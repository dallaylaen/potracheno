package Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.0501;

use DBI;
use Digest::MD5 qw(md5_base64);
use Time::Local qw(timelocal);

use parent qw(MVC::Neaf::X::Session);
use Potracheno::Config;

sub new {
    my ($class, %opt) = @_;

    if ($opt{config_file}) {
        $opt{config} = Potracheno::Config->load_config( $opt{config_file}, %opt )
            || $opt{config}; # fallback to defaults if file not found
    };

    $opt{status} = $opt{config}{status} || { 0 => "Closed", 1 => "Open" };

    my $self = bless \%opt, $class;

    $self->{dbh} = $self->get_dbh( $self->{config}{db} );

    return $self;
};

sub dbh { return $_[0]->{dbh} };

sub get_dbh {
    my ($self, $db) = @_;

    my ($type) = $db->{handle}=~ /dbi:([^:]+)/;
    if ($type eq 'SQLite') {
        return DBI->connect($db->{handle}, $db->{user}, $db->{pass},
            { RaiseError => 1, sqlite_unicode => 1 });
    } elsif($type eq 'mysql') {
        my $dbh = DBI->connect($db->{handle}, $db->{user}, $db->{pass},
            { RaiseError => 1 });
        $dbh->do('SET NAMES utf8;');
        return $dbh;
    };
    # TODO more DB types welcome

    warn "WARN Unknown DB is being used";
    return DBI->connect($db->{handle}, $db->{user}, $db->{pass},
        { RaiseError => 1 });
};

sub get_status {
    my ($self, $id) = @_;
    return $self->{status}{$id};
};

sub get_status_pairs {
    my $self = shift;

    # return status hash as a list of pairs, sorted by id
    return $self->{status_pairs} ||= [
        sort { $a->[0] <=> $b->[0] }
        map { [ $_ => $self->{status}{$_} ] }
        keys %{ $self->{status} }
    ];
};

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

my $sql_art_ins = "INSERT INTO issue(summary,body,user_id,created) VALUES(?,?,?,?)";
my $sql_art_sel = <<"SQL";
    SELECT a.issue_id AS issue_id, a.body AS body, a.summary AS summary
        , a.status_id AS status_id
        , a.user_id AS user_id, u.name AS author
        , a.created AS created
    FROM issue a JOIN user u ON a.user_id = u.user_id
    WHERE a.issue_id = ?;
SQL
sub add_issue {
    my ($self, %opt) = @_;

    my $t = time;

    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $sql_art_ins );
    $sth->execute( $opt{summary}, $opt{body}, $opt{user}{user_id}, $t );

    my $id = $dbh->last_insert_id("", "", "issue", "issue_id");

    return $id;
};

sub get_issue {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_art_sel );
    my $rows = $sth->execute( $opt{id} );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;
    return unless $data;

    $data->{seconds_spent} = $self->get_time( issue_id => $opt{id} );
    $data->{time_spent}    = $self->time2human( $data->{seconds_spent} );
    $data->{status}        = $self->{status}{ $data->{status_id} };

    return $data;
};

my $sql_time_ins = "INSERT INTO activity(user_id,issue_id,seconds,note,created) VALUES(?,?,?,?,?)";
my $sql_time_sum = "SELECT sum(seconds) FROM activity WHERE 1 = 1";
my $sql_issue_status = "UPDATE issue SET status_id = ? WHERE issue_id = ?";

# TODO rename to spent_time, solve_time
my @log_required = qw(user_id issue_id);
my @log_known = (@log_required, qw( note seconds fix_estimate created ));
sub log_activity {
    my ($self, %opt) = @_;

    my @missing = grep { !defined $opt{$_} } @log_required;
    $self->my_croak( "required args missing: @missing" )
        if @missing;

    $opt{created}    ||= time;
    $opt{seconds}      = $self->human2time( $opt{time} ) || undef;
    $opt{fix_estimate} = $self->human2time( $opt{solve_time} ) || undef;
    my $status         = $opt{status_id};

    return unless $opt{seconds} || $opt{fix_estimate} || $status || $opt{note};

    if (defined $status) {
        $self->{status}{ $status }
            or $self->my_croak("Illegal status_id $status");
        my $sth_st = $self->dbh->prepare( $sql_issue_status );
        $sth_st->execute( $status, $opt{issue_id} );
        $opt{note} = "Status changed to $self->{status}{ $status }"
            . ( defined $opt{note} ? "\n\n$opt{note}" : "");
    };

    # TODO orm it?
    # Make sql request
    my @fields;
    my @values;
    foreach (@log_known) {
        defined $opt{$_} or next;
        push @fields, $_;
        push @values, $opt{$_};
    };
    my $quest = join ",", ("?") x @fields;
    my $into  = join ",", @fields;

    my $sth = $self->dbh->prepare( "INSERT INTO activity($into) VALUES ($quest)" );
    $sth->execute( @values );
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
    t.activity_id AS activity_id,
    t.issue_id AS issue_id,
    t.user_id AS user_id,
    u.name AS user_name,
    t.seconds AS seconds,
    t.fix_estimate AS solve_time_s,
    t.note AS note,
    t.created AS created
FROM activity t JOIN user u USING(user_id)
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
        $data->{solve_time} = $self->time2human($data->{solve_time_s});
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
SELECT issue_id, 0 AS comment_id, body, summary, status_id, created
FROM issue WHERE
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

    my $order = "ORDER BY created DESC"; # TODO $opt{sort}

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
        $row->{status} = $self->{status}{ $row->{status_id} };
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
    die $@ if $@ and $@ !~ /unique|Duplicate/i;

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
$time_unit_re = qr/(?:$time_unit_re)/;
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

    return 0 unless $t;

    my @ret;
    foreach (@unit_desc) {
        $t >= $_ or next;
        push @ret, int($t/$_).$unit_time{$_};
        $t = $t % $_;
    };

    return @ret ? join " ", @ret : '0';
};

my $sql_rep = <<'SQL';
SELECT
    i.issue_id                AS issue_id,
    i.summary                 AS summary,
    i.body                    AS body,
    i.user_id                 AS author_id,
    u.name                    AS author_name,
    i.created                 AS created,
    i.status_id               AS status_id,
    MAX(a.created)            AS last_modified,
    SUM(a.seconds)            AS time_spent_s,
    COUNT(distinct a.user_id) AS participants,
    MAX(a.fix_estimate)       AS has_solution
FROM issue i LEFT JOIN activity a USING( issue_id )
    JOIN user u ON i.user_id = u.user_id
WHERE 1 = 1 %s
GROUP BY a.issue_id
HAVING 1 = 1 %s
ORDER BY %s
SQL

sub report_order_options {
    return _pairs(
         issue_id       => "id",
         summary        => "Summary",
         author_name    => "Author",
         created        => "Creation date",
         status_id      => "Status",
         last_modified  => "Modification date",
         time_spent_s   => "Time spent",
         participants   => "Number of backers",
         has_solution   => "Solution availability",
    );
};

sub report {
    my ($self, %opt) = @_;

    my @where;
    my @having;
    my $order  = 'created DESC';
    my @param;

    if ($opt{order_by} and $opt{order_dir}) {
        $order = "$opt{order_by} $opt{order_dir}";
    };

    if ($opt{date_from}) {
        $opt{date_from} =~ /(\d+)\D+(\d+)\D+(\d+)/ or die "Bad date format";
        my $t = timelocal(0,0,0,$3,$2-1,$1);
        push @where, "a.created >= ?";
        push @param, $t;
    };
    if ($opt{date_to}) {
        $opt{date_to} =~ /(\d+)\D+(\d+)\D+(\d+)/ or die "Bad date format";
        my $t = timelocal(59,59,23,$3,$2-1,$1);
        push @where, "a.created <= ?";
        push @param, $t;
    };
    if (defined $opt{status}) {
        push @where, "NOT " x !!$opt{status_not} . "i.status_id = ?";
        push @param, $opt{status};
    };
    if (defined $opt{has_solution}) {
        push @having, "NOT " x !$opt{has_solution} . "has_solution = 0";
    };

    my $sql = sprintf( $sql_rep
        , (join ' AND ', '', @where), (join ' AND ', '', @having), $order );
    warn "DEBUG report: sql = $sql";
    my $sth = $self->dbh->prepare( $sql );
    $sth->execute(@param);

    my @report;
    while (my $row = $sth->fetchrow_hashref) {
        $row->{time_spent} = $self->time2human( $row->{time_spent_s} );
        $row->{status} = $self->get_status( $row->{status_id} );
        push @report, $row;
    };

    return \@report;
};

sub _pairs {
    my @ret;
    while (@_) {
        push @ret, [shift, shift];
    };
    return \@ret;
};

my @tables = qw(user issue activity);
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
