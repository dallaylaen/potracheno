package Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.0305;

use DBI;
use Digest::MD5 qw(md5_base64);

use parent qw(MVC::Neaf::X::Session);
use Potracheno::Config;

sub new {
    my ($class, %opt) = @_;

    if ($opt{config_file}) {
        $opt{config} = Potracheno::Config->load_config( $opt{config_file}, %opt )
            || $opt{config}; # fallback to defaults if file not found
    };

    my $self = bless \%opt, $class;

    my $db = $self->{config}{db};
    $self->{dbh} = DBI->connect($db->{handle}, $db->{user}, $db->{pass},
        { RaiseError => 1 });

    return $self;
};

sub dbh { return $_[0]->{dbh} };

my $sql_user_by_id   = "SELECT user_id,name FROM user WHERE user_id = ?";
my $sql_user_by_name = "SELECT user_id,name FROM user WHERE name = ?";
my $sql_user_insert  = "INSERT INTO user(name) VALUES(?)";

sub load_user {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id name)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };
    $self->my_croak( "No conditions found" ) unless @arg;

    my $sth = $self->{dbh}->prepare( "SELECT * FROM user WHERE 1 = 1".$where );
    $sth->execute(@arg);

    my ($data) = $sth->fetchrow_hashref;
    $sth->finish;
    return $data;
};

sub login {
    my ($self, $name, $pass) = @_;

    my $user = $self->load_user( name => $name );

    return unless $user;
    return unless $self->check_pass( $user->{password}, $pass );

    return $user;
};

my $sql_user_ins = <<'SQL';
INSERT INTO user(name,password) VALUES (?,?);
SQL

# TODO refactor into (insert stub, save_user)
sub add_user {
    my ($self, $user, $pass) = @_;

    my $crypt = $self->make_pass( $self->get_session_id, $pass );
    my $sth = $self->dbh->prepare( $sql_user_ins );
    eval {
        $sth->execute( $user, $crypt );
    };
    return if ($@ =~ /unique/);
    die $@ if $@; # rethrow

    my $id = $self->dbh->last_insert_id("", "", "user", "user_id");
    return $id;
};


sub save_user {
    my ($self, $data) = @_;

    my $id = $data->{user_id};
    $self->my_croak("User id required")
        unless $id;

    my %new;
    $new{password} = $self->make_pass( $self->get_session_id, $data->{pass} )
        if defined $data->{pass};
    # TODO more options here

    return unless %new;

    # Here's some ORM going on :)
    my @order = sort keys %new;
    my $set = join ", ", map { "$_=?" } @order;

    my $sth = $self->dbh->prepare("UPDATE user SET $set WHERE user_id = ?");
    $sth->execute( @new{@order}, $id );
    $sth->finish;
    return $id;
};

sub check_pass {
    my ($self, $salt, $pass) = @_;

    return $self->make_pass( $salt, $pass ) eq $salt;
};

sub make_pass {
    my ($self, $salt, $pass) = @_;

    $salt =~ s/#.*//;
    return join '#', $salt, md5_base64( join '#', $salt, $pass );
};

my $sql_art_ins = "INSERT INTO issue(summary,body,author_id,posted) VALUES(?,?,?,?)";
my $sql_art_sel = <<"SQL";
    SELECT a.issue_id AS issue_id, a.body AS body, a.summary AS summary
        , a.author_id AS author_id, u.name AS author
        , a.posted AS posted
    FROM issue a JOIN user u ON a.author_id = u.user_id
    WHERE a.issue_id = ?;
SQL
sub add_issue {
    my ($self, %opt) = @_;

    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $sql_art_ins );
    $sth->execute( $opt{summary}, $opt{body}, $opt{user}{user_id}, time );

    my $id = $dbh->last_insert_id("", "", "issue", "issue_id");
    return $id;
};

sub get_issue {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_art_sel );
    my $rows = $sth->execute( $opt{id} );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;

    $data->{seconds_spent} = $self->get_time( issue_id => $opt{id} );
    $data->{time_spent}    = $self->time2human( $data->{seconds_spent} );

    return $data;
};

my $sql_time_ins = "INSERT INTO time_spent(user_id,issue_id,seconds,note,posted) VALUES(?,?,?,?,?)";
my $sql_time_sum = "SELECT sum(seconds) FROM time_spent WHERE 1 = 1";
sub add_time {
    my ($self, %opt) = @_;

    my $time = $self->human2time( $opt{time} );

    my $sth = $self->{dbh}->prepare( $sql_time_ins );
    $sth->execute( $opt{user_id}, $opt{issue_id}, $time
        , $opt{note}, $opt{posted} || time );
};

sub get_time {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id issue_id)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };

    my $sth = $self->{dbh}->prepare( $sql_time_sum . $where );
    $sth->execute( @arg );

    my ($t) = $sth->fetchrow_array;
    $t ||= 0;
    return $t;
};

my $sql_time_sel = "SELECT
    t.time_spent_id AS time_spent_id,
    t.issue_id AS issue_id,
    t.user_id AS user_id,
    u.name AS user_name,
    t.seconds AS seconds,
    t.note AS note,
    t.posted AS posted
FROM time_spent t JOIN user u USING(user_id)
WHERE 1 = 1";
sub get_comments {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id issue_id)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };
    my $sort = '';
    if ($opt{sort}) {
        $opt{sort} =~ /^([-+]?)(\w+)/;
        my $by = $2;
        my $desc = $1 eq '-' ? ' DESC' : '';
        $sort = " ORDER BY $by$desc";
    };

    my $sth = $self->{dbh}->prepare( $sql_time_sel . $where . $sort );
    $sth->execute( @arg );

    my @ret;
    while (my $data = $sth->fetchrow_hashref) {
        $data->{time} = $self->time2human($data->{seconds});
        push @ret, $data;
    };

    if ($opt{sort}) {
        $opt{sort} =~ /^([-+]?)(\w+)/;
        my $by = $2;
        my $desc = $1 eq '-' ? 1 : 0;
        use warnings FATAL => 'all';
        @ret = sort { $a->{$by} <=> $b->{$by} } @ret;
        @ret = reverse @ret if $desc;
    };

    return \@ret;
};

my $sql_search_art = <<"SQL";
SELECT issue_id, 0 AS comment_id, body, summary, posted FROM issue WHERE
SQL

sub search {
    my ($self, %opt) = @_;

    my $terms = $opt{terms};
    return [] unless $terms and ref $terms eq 'ARRAY' and @$terms;

    my @terms_sql = map { my $x = $_; $x =~ tr/*?\\'/%___/; "%$x%" } @$terms;
    my @terms_re  = map {
        my $x = $_; $x =~ tr/?/./; $x =~ s/\*/.*/g; $x =~ s/\\/\\\\/g; $x
    } @$terms;
    my $match_re  = join "|", @terms_re;
    $match_re     = qr/(.{0,40})($match_re)(.{0,40})/;

    my $where = join ' AND '
        , map { "(body LIKE '$_' OR summary LIKE '$_')" } @terms_sql;

    my $order = "ORDER BY posted DESC"; # TODO $opt{sort}

    my $sth = $self->{dbh}->prepare( "$sql_search_art $where $order" );
    $sth->execute;

    my @result;
    FETCH: while ( my $row = $sth->fetchrow_hashref ) {
        my @snip;
        foreach my $t( @terms_re ) {
            $row->{summary} =~ /(.{0,40})($t)(.{0,40})/i
                or $row->{body} =~ /(.{0,40})($t)(.{0,40})/i
                or next FETCH;
            push @snip, [ $1, $2, $3 ];
        };
        $row->{snippets} = \@snip;
        push @result, $row;
    };

    return \@result;
};

my $sql_sess_load = <<'SQL';
SELECT u.user_id, u.name
FROM user u JOIN sess s USING(user_id)
WHERE s.sess_id = ?
SQL

my $sql_sess_upd = <<'SQL';
UPDATE sess SET user_id = ? WHERE sess_id = ?
SQL

sub load_session {
    my ($self, $id) = @_;

    my $sth = $self->dbh->prepare($sql_sess_load);

    $sth->execute( $id );
    my ($user_id, $name) = $sth->fetchrow_array;
    $sth->finish;

    return { user_id => $user_id, user_name => $name };
};

sub save_session {
    my ($self, $id, $data) = @_;

    my $sth_ins = $self->dbh->prepare(
        "INSERT INTO sess(sess_id,user_id,created) VALUES (?,?,?)" );
    eval {
        $sth_ins->execute($id, $data->{user_id}, time);
    };
    # ignore insert errors
    die $@ if $@ and $@ !~ /unique/i;

    my $sth = $self->dbh->prepare($sql_sess_upd);
    $sth->execute( $data->{user_id}, $id );
};

my %time_unit = (
    s => 1,
    m => 60,
    h => 60*60,
    d => 60*60*24,
    w => 60*60*24*7,
    mon => 60*60*24*30,
    y => 60*60*24*365,
);
my $time_unit_re = join "|", reverse sort keys %time_unit;
$time_unit_re = qr/(?:$time_unit_re|)/;
my $num_re = qr/(?:\d+(?:\.\d+)?)/; # no minus, no sophisticated stuff

sub human2time {
    my ($self, $str) = @_;

    my $t = 0;
    return $t unless $str;
    while ( $str =~ /($num_re)\s*($time_unit_re)/g ) {
        $t += $1 * $time_unit{$2 || 'h'};
    };

    return int($t);
};

my %unit_time = reverse %time_unit;
my @unit_desc = sort { $b <=> $a } keys %unit_time;
sub time2human {
    my ($self, $t) = @_;

    my @ret;
    foreach (@unit_desc) {
        $t >= $_ or next;
        push @ret, int($t/$_).$unit_time{$_};
        $t = $t % $_;
    };

    return @ret ? join " ", @ret : '0';
};

my @tables = qw(user issue time_spent);
sub dump {
    my $self = shift;

    my %dump;
    my $dbh = $self->dbh;
    foreach my $t (@tables) {
        my $sth = $dbh->prepare( "SELECT * FROM $t" );
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @{ $dump{$t} }, $row;
        };
    };

    return \%dump;
};

sub restore {
    my ($self, $dump) = @_;

    my $dbh = $self->dbh;
    $dbh->begin_work;
    local $SIG{__DIE__} = sub { $dbh->rollback };
    foreach my $t (@tables) {
        next unless $dump->{$t};
        foreach my $row( @{ $dump->{$t} } ) {
            defined $row->{$_} or delete $row->{$_}
                for keys %$row;
            my @keys = sort keys %$row;
            next unless @keys;
            my @values = @$row{@keys};
            my $into  = join ",", @keys;
            my $quest = join ",", ("?") x @keys;
            my $sth = $dbh->prepare_cached("INSERT INTO $t($into) VALUES ($quest)");
            $sth->execute( @values );
        };
    };

    $dbh->commit;
};

1;
