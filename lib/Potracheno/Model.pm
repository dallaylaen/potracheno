package Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.0101;

use DBI;

sub new {
    my ($class, %opt) = @_;

    my $self = bless \%opt, $class;

    $self->{dbh} = DBI->connect($opt{db_handle}, $opt{db_user}, $opt{db_pass},
        { RaiseError => 1 });

    return $self;
};

my $sql_user_by_id   = "SELECT user_id,name FROM user WHERE user_id = ?";
my $sql_user_by_name = "SELECT user_id,name FROM user WHERE name = ?";
my $sql_user_insert  = "INSERT INTO user(name) VALUES(?)";

sub get_user {
    my ($self, %opt) = @_;

    my $name = $opt{name};

    my $dbh = $self->{dbh};
    my $sth_insert = $dbh->prepare($sql_user_insert);
    my $sth_select = $dbh->prepare($sql_user_by_name);

    $sth_select->execute( $name );
    if (my $data = $sth_select->fetchrow_hashref) {
        return $data;
    };

    $sth_insert->execute( $name );
    $sth_select->execute( $name );
    if (my $data = $sth_select->fetchrow_hashref) {
        return $data;
    };
    die "Failed to either find or create user name=$name";
};


my $sql_art_ins = "INSERT INTO article(summary,body,author_id) VALUES(?,?,?)";
my $sql_art_sel = <<"SQL";
    SELECT a.article_id AS article_id, a.body AS body, a.summary AS summary
        , a.author_id AS author_id, u.name AS author
    FROM article a JOIN user u ON a.author_id = u.user_id
    WHERE a.article_id = ?;
SQL
sub add_article {
    my ($self, %opt) = @_;

    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $sql_art_ins );
    $sth->execute( $opt{summary}, $opt{body}, $opt{user}{user_id} );

    my $id = $dbh->last_insert_id("", "", "article", "article_id");
    return $id;
};

sub get_article {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_art_sel );
    my $rows = $sth->execute( $opt{id} );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;

    $data->{time_spent} = $self->get_time( article_id => $opt{id} );

    return $data;
};

my $sql_time_ins = "INSERT INTO time_spent(user_id,article_id,seconds) VALUES(?,?,?)";
my $sql_time_sel = "SELECT sum(seconds) FROM time_spent WHERE 1 = 1";
sub add_time {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_time_ins );
    $sth->execute( $opt{user_id}, $opt{article_id}, $opt{time} );
};

sub get_time {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id article_id)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };

    my $sth = $self->{dbh}->prepare( $sql_time_sel . $where );
    $sth->execute( @arg );

    my ($t) = $sth->fetchrow_array;
    $t ||= 0;
    return $t;
};

1;
