package App::Its::Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.0901;

=head1 NAME

App::Its::Potracheno::Model - The data model for tech debt ITS.

=head1 DESCRIPTION

This Model contains methods to access user, issue, time tracking, etc. data.

Data is stored in a SQL database.

Model is instantiated and requires config.

Also some presentation methods are currently here (HTML escping + markdown).

=head1 METHODS

=cut

use DBI;
use Digest::MD5 qw(md5_base64);
use Time::Local qw(timelocal);
use Data::Dumper;
use Text::Markdown qw(markdown);

# We'll also work as a session storage
use parent qw(MVC::Neaf::X::Session);

# TODO use config from CPAN instead
use App::Its::Potracheno::Config;

=head2 new (%options)

%options:

=over

=item * config - hash with parameters

=item * config_file - file with parameters

=item * dbh - provide database handler

=back

=cut

sub new {
    my ($class, %opt) = @_;

    if ($opt{config_file}) {
        $opt{config} = App::Its::Potracheno::Config->load_config( $opt{config_file}, %opt )
            || $opt{config}; # fallback to defaults if file not found
    };

    $opt{status} = $opt{config}{status} || { 1 => "Open", 100 => "Closed" };
    my @bad_status = grep { !/^\d+$/ || $_ < 1 || $_ > 100 }
        keys %{ $opt{status} };
    $class->my_croak("Bad status ids @bad_status")
        if @bad_status;

    my $self = bless \%opt, $class;

    $self->{dbh} ||= $self->get_dbh( $self->{config}{db} );

    return $self;
};

=head2 get_config

Return the config hash.

=cut

sub get_config {
    my $self = shift;

    return $self->{config} unless @_;
    my $section = shift;
    return $self->{config}{$section} unless @_;
    return $self->{config}{$section}{ + shift };
};

=head1 CONFIG FORMAT

The config hash is expected to contain the following:

    {db}
        {handle}
        {user} # not required for sqlite
        {pass}

    {status}
        {0}
        {1}
        other numbers

    {search}
        {limit} # not required

=cut

=head2 dbh()

Return database handler.

=cut

sub dbh { return $_[0]->{dbh} };

=head2 get_dbh($config)

Connect to database using config information.
This is performed in new(), no need to do manually.

=cut

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

=head2 get_status( $id )

Resolve status id to name. Statuses are stored in config rather than db.

=cut

sub get_status {
    my ($self, $id) = @_;
    return $self->{status}{$id};
};

=head2 get_status_pairs()

Return (id, name) pairs for all known issue statuses.
This is used to build E<lt>selectE<gt>'s.

=cut

sub get_status_pairs {
    my $self = shift;

    # return status hash as a list of pairs, sorted by id
    return $self->{status_pairs} ||= [
        sort { $a->[0] <=> $b->[0] }
        map { [ $_ => $self->{status}{$_} ] }
        keys %{ $self->{status} }
    ];
};

=head1 USER METHODS

=head1 load_user( %options )

Either user_id or name key is required.

=cut

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

=head2 login( name, password )

Log user into the system.
Returns load_user result if success, nothing otherwise.

=cut

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

=head2 add_user( name, password )

Create new user. To be rewritten.

=cut

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

=head2 save_user( \%user )

Saves user struct as returned by load_user();

Returns user id.

To be rewritten via save_any().

=cut

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

=head2 check_pass( $salted_pass, $plain_pass )

Return true if password matches.

=cut

sub check_pass {
    my ($self, $salt, $pass) = @_;

    return $self->make_pass( $salt, $pass ) eq $salt;
};

=head2 make_pass ( $salt, $plain_pass )

Encrypt password. md5 is used (should move to sha1?).

=cut

sub make_pass {
    my ($self, $salt, $pass) = @_;

    $salt =~ s/#.*//;
    return join '#', $salt, md5_base64( join '#', $salt, $pass );
};

=head1 ISSUE METHODS

=head2 save_issue( %issue )

Create a new issue, or update existing one if issue_id given.

=cut

sub save_issue {
    my ($self, %opt) = @_;

    my %data;
    $data{$_} = $opt{issue}{$_} for qw(issue_id body summary);
    my $user_id = $opt{user_id} || $opt{user}{user_id};

    # edit/create specials
    if ($data{issue_id}) {
        $self->log_activity(
            user_id => $user_id, issue_id => $data{issue_id}, note => "Edited issue" );
    } else {
        $data{user_id} = $user_id;
        $data{created} ||= time;
        $data{status_id} = 1 unless defined $data{status_id};
    };

    $self->my_croak("Unknown status_id $data{status_id}")
        if defined $data{status_id} and !$self->get_status( $data{status_id} );

    return $self->save_any( issue => issue_id => \%data );
};

=head2 get_issue

Load issue from database.

=cut

# why not load_issue?!

my $sql_art_sel = <<"SQL";
    SELECT a.issue_id AS issue_id, a.body AS body, a.summary AS summary
        , a.status_id AS status_id
        , a.user_id AS user_id, u.name AS author
        , a.created AS created
    FROM issue a JOIN user u ON a.user_id = u.user_id
    WHERE a.issue_id = ?;
SQL

sub get_issue {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_art_sel );
    my $rows = $sth->execute( $opt{id} );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;
    return unless $data;

    $data->{seconds_spent} = $self->get_time( issue_id => $opt{id} );
    $data->{status}        = $self->{status}{ $data->{status_id} };
    $data->{tags}          = $self->get_tags( issue_id => $opt{id} );
    $data->{tags_alpha}    = [ sort values %{ $data->{tags} } ];

    return $data;
};

=head2 log_activity( \%activity )

user_id and issue_id are mandatory.

Save spent time/comment/solution.

Also changes issue status, if status given.

=cut

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

    # Skip empty comments, sanitize otherwise
    if (defined $opt{note} and length $opt{note}) {
    } else {
        delete $opt{note}
    };

    return unless $opt{seconds} || $opt{fix_estimate} || defined $status || $opt{note};

    if (defined $status) {
        $self->{status}{ $status }
            or $self->my_croak("Illegal status_id $status");
        my $sth_st = $self->dbh->prepare( $sql_issue_status );
        $sth_st->execute( $status, $opt{issue_id} );
        $opt{note} = "Status changed to **$self->{status}{ $status }**"
            . ( defined $opt{note} ? "\n\n$opt{note}" : "");
    };

    # TODO Redo with save_any
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

=head2 get_time( user_id => ... || issue_id => ... )

Get spent time sum for given user/issue/both.

=cut

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

=head2 get_comments( user_id => ... || issue_id => ... )

Get whatever logged activity for user/issue as an arrayref of hashrefs.

=cut

my $sql_time_sel = "SELECT
    t.activity_id AS activity_id,
    t.issue_id AS issue_id,
    t.user_id AS user_id,
    u.name AS user_name,
    t.seconds AS seconds,
    t.fix_estimate AS fix_estimate,
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

    if ($opt{text_only}) {
        $where .= " AND t.note IS NOT NULL";
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
        $data->{note} = $self->render_text( $data->{note} )
            if $opt{render};
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

=head1 SEARCH

=head2 search( terms => [word, word ... ] )

SQL-based search is wrong. TODO replace with normal indexer.

=cut

my $sql_search_art = <<"SQL";
SELECT issue_id, 0 AS activity_id, body, summary, status_id, created
FROM issue WHERE
SQL

my $sql_search_comm = <<"SQL";
SELECT
    i.issue_id      AS issue_id,
    a.activity_id   AS activity_id,
    a.note          AS body,
    i.summary       AS summary,
    i.status_id     AS status_id,
    i.created       AS created
FROM issue i JOIN activity a USING(issue_id)
WHERE a.note IS NOT NULL AND
SQL

sub search {
    my ($self, %opt) = @_;

    my $terms = $opt{terms};
    return [] unless $terms and ref $terms eq 'ARRAY' and @$terms;

    # only search 5 terms using SQL, check the rest via perl
    my @terms_trunc = sort { length $b <=> length $a } @$terms;
    $#terms_trunc = 4 if $#terms_trunc > 4;

    my @terms_sql = map { my $x = $_; $x =~ tr/*?\\'/%___/; "%$x%" } @terms_trunc;
    my @terms_re  = map {
        my $x = $_; $x =~ tr/?/./; $x =~ s/\*/.*/g; $x =~ s/\\/\\\\/g; $x
    } @$terms;
    my $match_re  = join "|", @terms_re;
    $match_re     = qr/(.{0,40})($match_re)(.{0,40})/;

    my $where = join ' AND '
        , map { "(body LIKE '$_' OR summary LIKE '$_')" } @terms_sql;
    my $where2 = join ' AND '
        , map { "(a.note LIKE '$_' OR i.summary LIKE '$_')" } @terms_sql;

    my $order = "ORDER BY created DESC"; # TODO $opt{sort}

    my $sql = "SELECT * FROM (
            $sql_search_art $where UNION $sql_search_comm $where2
        ) AS temp $order";

    my $count;
    if ($opt{limit}) {
        $count = $opt{limit};
        $opt{limit} *= 10;
    };
    my $start_next = $opt{limit} && $opt{start} || 0;

    my %seen;
    $seen{$_}++ for split /\./, $opt{seen} || '';

    $opt{callback} = sub {
        $start_next++ if defined $count;

        my $row = shift;
        $seen{ $row->{issue_id} }++ and return -1;
        my @snip;
        foreach my $t( @terms_re ) {
            $row->{summary} =~ /(.{0,40})($t)(.{0,40})/i
                or $row->{body} =~ /(.{0,40})($t)(.{0,40})/i
                or return -1;
            push @snip, [ $1, $2, $3 ];
        };
        $row->{snippets} = \@snip;
        $row->{status} = $self->{status}{ $row->{status_id} };

        $count-- or return 0 if defined $count;
        return 1;
    };
    my $res = $self->_run_query($sql, [], \%opt);

    return wantarray ? ($res, $start_next) : $res;
};

=head1 SESSION

This implements L<MVC::Neaf::X::Session>.

=head2 load_session

=head2 save_session

=cut

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

# Non-DB methods

=head1 DATA CONVERTION METHODS

=cut

=head2 render_issue

Convert issue as fetched from DB into tpl-ready form.

Currenty only appies formatting to body.

=cut

sub render_issue {
    my ($self, $data) = @_;

    $data->{body} = $self->render_text( $data->{body} )
        if defined $data->{body};

    return $data;
};

=head2 filter_text

Convert text into HTML-safe form.
Uses home-brewn HTML escaping.

=cut

my %html_replace = qw(< &lt; > &gt; & &amp;);

sub filter_text {
    my ($self, $text) = @_;

    $text =~ s#([<>&])#$html_replace{$1}#g;
    return $text;
};

=head2 render_text

Apply safety procedures, custom tags, and markdown rendering.

custom tags include <code>, <quote>, and <plain>.

=cut

my $render_tags = qr(code|quote|plain);

sub render_text {
    my ($self, $text) = @_;

    # cut text code blocks & markdown blocks
    # process them separately
    my @slice;
    while ($text =~ s#^(.*?)<($render_tags)>(.*?)</\2>##gis) {
        my ($md, $tag, $special) = ($1, $2, $3);
        push @slice, $self->_md( $md );

        if (lc $tag eq 'code') {
            push @slice, '<pre class="code">'.$self->filter_text($special).'</pre>';
        } elsif (lc $tag eq 'quote') {
            push @slice, '<div class="quote">'.$self->_md( $special ).'</div>';
        } elsif (lc $tag eq 'plain') {
            push @slice, '<span class="plain">'.$self->filter_text( $special ).'</span>';
        };
    };
    push @slice, $self->_md( $text );

    # finally, combine all together
    return join "\n", @slice;
};

sub _md {
    my ($self, $text) = @_;

    $text =~ s/#(\d+)/[#$1](\/issue\/$1)/g;
    $text = $self->filter_text($text);
    return markdown( $text );
}

=head2 human2time

=head2 time2human

Convert seconds to and from "1w 2d 3h 4m 5s".

"Spent 2 weeks on vacation" will also render as 2w, yielding 1+ million.

=cut

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

    return unless defined $str;
    return $1 if $str =~ /^(\d+)(\.\d*)?$/;

    my $t = 0;
    while ( $str =~ /($num_re)\s*($time_unit_re)/g ) {
        $t += $1 * $time_unit{$2};
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

=head2 date2time

Convert date to seconds.

Currently seconds are stored in DB to avoid mysql/sqlite compatibility issues.
This MAY change in the future.

=cut

sub date2time {
    my ($self, $date) = @_;

    # seconds pass through
    $date =~ /^(\d+)$/
        and return $1;

    $date =~ /(\d\d\d\d)\D+(\d\d?)\D+(\d\d?)(?:\D+(\d\d?):(\d\d?))?/
        or $self->croak( "Wrong date format" );

    return timelocal(0,$5||0,$4||0,$3,$2-1,$1);
};

=head1 AGGREGATE REPORTS

=head2 browse_order_options()

Return pairs of values for ordering browse page, seady to be used by
E<lt>selectE<gt>.

=cut

sub browse_order_options {
    return _pairs(
        issue_id       => "id",
        summary        => "Summary",
        author_name    => "Author",
        created        => "Creation date",
        status_id      => "Status",
        last_modified  => "Modification date",
        time_spent   => "Time spent",
        participants   => "Number of backers",
        best_estimate   => "Solution estimate",
    );
};

=head2 browse( %options )

Return issues as selected by parameters.

=cut

# TODO document params

my @bound_aggregate = qw(last_modified created participants time_spent best_estimate activity_count);
my @bound_issue    = qw(created);
my @bound_activity = qw(created);
my @report_options_time = qw(time_spent best_estimate);
my @report_options_date = qw(i_created a_created);

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
    SUM(a.seconds)            AS time_spent,
    COUNT(distinct a.user_id) AS participants,
    COUNT(a.activity_id)      AS activity_count,
    COUNT(s.activity_id)      AS has_solution,
    MIN(s.fix_estimate)       AS best_estimate
FROM issue i
    JOIN user u ON i.user_id = u.user_id
    LEFT JOIN activity a USING( issue_id )
    LEFT JOIN activity s ON s.issue_id = i.issue_id AND s.fix_estimate > 0
    %s
WHERE %s
GROUP BY i.issue_id
HAVING %s
SQL

sub browse {
    my ($self, %opt) = @_;

    my @where;
    my @having;
    my @param;
    my @extra;

    $opt{order_by}  ||= 'created';
    $opt{order_dir}   = 1 unless defined $opt{order_dir};

    $self->_prepare_time( \%opt );

    # EXTRA TABLES
    if ($opt{tag}) {
        my $tag = $self->fetch_tags( tags => [$opt{tag}] );
        return [] unless keys %$tag;
        push @extra, "JOIN issue_tag t ON i.issue_id = t.issue_id AND t.tag_id = ?";
        push @param, [keys %$tag]->[0]; # we know there's 1 key only
    };

    # ACTIVITY OPTIONS
    # must go first or else we filter out silent issues
    _select_activity( \@where, \@param, \%opt );

    # If any bounds placed on activity, make sure issues w/o activity
    # aren't selected
    if (@where) {
        push @having, "activity_count > 0";
    };

    # ISSUE OPTIONS
    _select_issue ( \@where, \@param, \%opt );

    # AGGREGATE OPTIONS
    if (defined $opt{has_solution}) {
        if ($opt{has_solution} > 1) {
            push @having, "best_estimate * ? < time_spent";
            push @param, $opt{pi_factor} || 4*atan2 1,1;
        } else {
            push @having, $opt{has_solution}
                ? "has_solution > 0"
                : "has_solution = 0";
        };
    };

    foreach (@bound_aggregate) {
        # +0 is to work around a bug, see perldoc DBD::SQLite
        if( defined $opt{"min_$_"} ) {
            push @having, "$_ >= ?+0";
            push @param, $opt{"min_$_"};
        };
        if( defined $opt{"max_$_"} ) {
            push @having, "$_ <= ?+0";
            push @param, $opt{"max_$_"};
        };
    };

    # MAKE SQL
    my $sql = sprintf( $sql_rep
        , (join "\n", @extra)
        , (join ' AND ', @where)||'1=1'
        , (join ' AND ', @having)||'1=1');

    return $self->_run_query( $sql, \@param, \%opt );
}; # end sub browse


# TODO do something about these!
sub _prepare_time {
    my ($self, $opt) = @_;

    exists $$opt{$_} and $$opt{$_} = $self->human2time( $$opt{$_} )
        foreach map { $_ => "min_$_" => "max_$_" } @report_options_time;
    exists $$opt{$_} and $$opt{$_} = $self->date2time( $$opt{$_} )
        foreach map { $_ => "min_$_" => "max_$_" } @report_options_date;
};

sub _select_activity {
    my ($where, $param, $opt) = @_;

    foreach (@bound_activity) {
        if( defined $opt->{"min_a_$_"} ) {
            push @$where, "a.$_ >= ?";
            push @$param, $opt->{"min_a_$_"};
        };
        if( defined $opt->{"max_a_$_"} ) {
            push @$where, "a.$_ <= ?";
            push @$param, $opt->{"max_a_$_"};
        };
    };
};

sub _select_issue {
    my ($where, $param, $opt) = @_;

    if (defined $$opt{status}) {
        push @$where, "NOT " x !!$$opt{status_not} . "i.status_id = ?";
        push @$param, $$opt{status};
    };
    foreach (@bound_issue) {
        if( defined $$opt{"min_i_$_"} ) {
            push @$where, "i.$_ >= ?";
            push @$param, $$opt{"min_i_$_"};
        };
        if( defined $$opt{"max_i_$_"} ) {
            push @$where, "i.$_ <= ?";
            push @$param, $$opt{"max_i_$_"};
        };
    };
};

# WATCHES

=head2 add_watch( %options )

Start watching an issue. issue_id and user_id is required.

=cut

sub add_watch {
    my ($self, %opt) = @_;

    my @missing = grep { !$opt{$_} } qw(user_id issue_id);
    $self->my_croak("missing  required parameters: @missing")
        if @missing;

    $opt{created} ||= time;

    # TODO foolproof?
    return $self->insert_any( watch => watch_id => \%opt )
        unless $self->get_watch( %opt )->[0];
};

=head2 del_watch( %options )

Opposite of add watch.

=cut

sub del_watch {
    my ($self, %opt) = @_;

    my @missing = grep { !$opt{$_} } qw(user_id issue_id);
    $self->my_croak("missing  required parameters: @missing")
        if @missing;

    my $sth = $self->dbh->prepare( "DELETE FROM watch WHERE user_id = ? AND issue_id = ?" );
    $sth->execute( $opt{user_id}, $opt{issue_id} );
};

my $sql_get_watch = <<"SQL";
    SELECT count(distinct me.user_id), count(distinct us.user_id)
    FROM watch us LEFT JOIN watch me
    ON me.watch_id = us.watch_id AND me.user_id = ?
    WHERE us.issue_id = ?
SQL

=head2 get_watch

Return a pair (me_watching=0|1, total_watchers=nnn).

If user_id not given, me_watching is 0.

=cut

sub get_watch {
    my ($self, %opt) = @_;

    my @missing = grep { !$opt{$_} } qw(issue_id);
    $self->my_croak("missing  required parameters: @missing")
        if @missing;

    my $sql = $opt{user_id} ? $sql_get_watch
        : "SELECT 0, count(distinct user_id) FROM watch WHERE issue_id = ?";

    my $sth = $self->dbh->prepare( $sql );
    $sth->execute( $opt{user_id} ? $opt{user_id} : (), $opt{issue_id} );
    return $sth->fetchrow_arrayref;
};

=head2 watch_feed( %options )

Get wathed issue activity feed, with filters.

user_id is required.

=cut

my $sql_watch_feed = <<"SQL";
    SELECT
        a.activity_id   AS activity_id,
        a.issue_id      AS issue_id,
        a.user_id       AS user_id,
        u.name          AS user_name,
        a.seconds       AS seconds,
        a.fix_estimate  AS fix_estimate,
        a.note          AS note,
        a.created       AS created
    FROM watch w
        JOIN activity a USING(issue_id)
        JOIN user u ON a.user_id = u.user_id
    WHERE %s
SQL

sub watch_feed {
    my ($self, %opt) = @_;

    $opt{user_id} or $self->my_croak("user_id missing");

    my @where = ("w.user_id = ?");
    my @param = ($opt{user_id});

    if ($opt{min_created}) {
        push @where, "a.created >= ?";
        push @param, $self->date2time( $opt{min_created} );
    };
    if ($opt{max_created}) {
        push @where, "a.created <= ?";
        push @param, $self->date2time( $opt{max_created} );
    };
    if (!$opt{all}) {
        push @where, "note IS NOT NULL";
    };

    my $sql = sprintf( $sql_watch_feed, (join ' AND ', @where) );
    return $self->_run_query( $sql, \@param, \%opt );
};

# TAGS

=head2 fetch_tags ( tags => [tag_name, tag_name ... ] )

Return { tag_id => tag_name, ... } for tags in database.

If C<create> option given, creates missing tags.

=cut

sub fetch_tags {
    my ($self, %opt) = @_;

    my $tags = $opt{tags};
    return {} unless $tags and @$tags;

    # uniq
    my %seen;
    $seen{$_}++ for @$tags;
    @$tags = keys %seen;

    # create select
    my $in = join ",", ("?") x @$tags;
    my $sql_sel = "SELECT tag_id, name FROM tag WHERE name IN ($in)";

    my %id_tag;

    # load known
    my $sth = $self->dbh->prepare( $sql_sel );
    $sth->execute( @$tags );
    while (my @row = $sth->fetchrow_array) {
        $id_tag{$row[0]} = $row[1];
        delete $seen{$row[1]};
    };

    if ($opt{create}) {
        foreach ( keys %seen ) {
            my $id = $self->insert_any( tag => tag_id => { name => $_ } );
            $id_tag{$id} = $_;
        };
    };

    return \%id_tag;
};

=head2 tag_issue( %opt )

Set tags on an issue.

issue_id is required.

tags => [tag_name, ...] sets new tags (if any).

Will remove any existing tags.

=cut

sub tag_issue {
    my ($self, %opt) = @_;

    my $issue = $opt{issue_id}
        or $self->my_croak("issue_id is required");

    my $tags = $self->fetch_tags( tags => $opt{tags}, create => 1 );

    my $del = $self->dbh->prepare( "DELETE FROM issue_tag WHERE issue_id = ?" );
    $del->execute( $issue );

    foreach (keys %$tags) {
        $self->insert_any( issue_tag => issue_tag_id =>
            { issue_id => $issue, tag_id => $_ } );
    };

    return $self;
};

=head2 get_tags( issue_id => nnn )

Fetch tags on an issue.

=cut

# TODO rename to get_issue_tags?..

my $sql_sel_tag = <<"SQL";
    SELECT t.tag_id, t.name
    FROM issue_tag i JOIN tag t USING(tag_id)
    WHERE issue_id = ?
SQL

sub get_tags {
    my ($self, %opt) = @_;

    my $issue = $opt{issue_id}
        or $self->my_croak("issue_id is required");

    my $sth = $self->dbh->prepare( $sql_sel_tag );
    $sth->execute( $issue );

    my %id_tag;
    while (my @row = $sth->fetchrow_array) {
        $id_tag{$row[0]} = $row[1];
    };

    return \%id_tag;
};

=head2 get_tags_stats( %options )

Get statistics by tags. Works similar to browse(), but aggregates by tag
and not by issue.

=cut

my $sql_tag_stat = <<"SQL";
SELECT
    t.tag_id                   AS tag_id,
    t.name                     AS name,
    count(distinct i.issue_id) AS issues,
    count(distinct a.user_id)  AS participants,
    count(distinct w.user_id)  AS watchers,
    sum(a.seconds)             AS time_spent,
    max(a.created)             AS last_modified
FROM tag t
    LEFT JOIN issue_tag it USING(tag_id)
    LEFT JOIN issue i    ON it.issue_id = i.issue_id
    LEFT JOIN watch w    ON it.issue_id = w.issue_id
    LEFT JOIN activity a ON it.issue_id = a.issue_id
WHERE %s
GROUP BY t.tag_id
HAVING %s
SQL
sub get_tag_stats {
    my ($self, %opt) = @_;

    my @where;
    my @having;
    my @param;

    $self->_prepare_time( \%opt );
    _select_activity( \@where, \@param, \%opt );
    _select_issue(    \@where, \@param, \%opt );

    if (defined $opt{tag_like} and length $opt{tag_like}) {
        push @where, "t.name LIKE ?";
        push @param, "%$opt{tag_like}%";
    };

    my $sql = sprintf( $sql_tag_stat
        , (join ' AND ', @where)||'1=1', (join ' AND ', @having) || '1=1' );

    return $self->_run_query( $sql, \@param, \%opt );
};

=head2 get_stats_total( %options )

Get total aggregate stats. Similar to browse.

=cut

# TODO Merge all reporting subs where possible!
my $sql_stat_total = <<"SQL";
SELECT
    count(distinct i.issue_id) AS issues,
    count(distinct a.user_id)  AS participants,
    count(distinct w.user_id)  AS watchers,
    sum(a.seconds)             AS time_spent,
    max(a.created)             AS last_modified
FROM issue i
    LEFT JOIN watch w ON i.issue_id = w.issue_id
    LEFT JOIN activity a ON i.issue_id = a.issue_id
WHERE %s
SQL
sub get_stats_total {
    my ($self, %opt) = @_;

    my @where;
    my @param;

    $self->_prepare_time( \%opt );
    _select_activity( \@where, \@param, \%opt );
    _select_issue(    \@where, \@param, \%opt );

    my $sql = sprintf( $sql_stat_total, (join ' AND ', @where)||'1=1' );

    return $self->_run_query( $sql, \@param, {} )->[0];
};

=head1 BACKUP & ORM PROCEDURES

=head2 dump

=head2 restore

Convert a live DB to and from hashref:

{ table => [ { row }, {row}, ... ], ... }

Used to migrate database.

=cut

my @tables = qw(user issue activity watch tag issue_tag);
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
            $self->insert_any($t, undef, $row);
        };
    };

    $dbh->commit;
};

# IN-PLACE ORM - TODO use DBIx::Record?

# input: SQL with (?), parameter list,
#    options = { count_only 0|1, orber_by, order_dir 0|1, limit, start }
# output: if count_only given, hashref { n = count }
# else array of hashrefs with sorting & limits applied.
sub _run_query {
    my ($self, $sql, $param, $opt) = @_;

    if ($opt->{count_only}) {
        $sql = "SELECT count(*) AS n FROM ( $sql ) AS temp_count";
    } else {
        if ($opt->{order_by}) {
            $sql .= " ORDER BY $opt->{order_by} "
                 .  ($opt->{order_dir} ? "DESC" : "ASC");
        };
        if ($opt->{limit}) {
            $sql .= " LIMIT ?,?";
            push @$param, $opt->{start} || 0, $opt->{limit};
        };
    };

    my $caller = [ caller(1) ]->[3];
    $caller    =~ s/.*:://;
    my $pkg    = ref $self || $self;

    warn "DEBUG $pkg->$caller: SQL = $sql; param=[@$param]";
    my $sth = $self->dbh->prepare( $sql );
    $sth->execute( @$param );

    if ($opt->{count_only}) {
        my $data = $sth->fetchrow_hashref;
        $sth->finish;
        return $data;
    };

    my @res;
    my $code = $opt->{callback};
    while (my $row = $sth->fetchrow_hashref) {
        if ($code) {
            my $reply = $code->( $row );
            warn "DEBUG check callback: $reply";
            $reply or last;
            $reply < 0 and next;
        };
        push @res, $row;
    };
    $sth->finish;
    return \@res;
};

=head2 save_any( table, id_fields, \%data )

INSERT or UPDATE data, based on whether id_field is present.

Returns value of that id_field, or 1 if none specified.

=cut

sub save_any {
    my ($self, $table, $key, $data) = @_;

    if( defined $data->{$key}) {
        return $self->update_any($table, $key, $data);
    } else {
        return $self->insert_any($table, $key, $data);
    };
};

=head2 save_any( table, id_fields, \%data )

INSERT data into table.

Returns value of id_field if present, last_insert_id if autogenerated,
or 1 if none specified.

=cut

sub insert_any {
    my ($self, $table, $key, $data) = @_;

    my (@keys, @values);
    foreach (keys %$data) {
        defined $data->{$_} or next;
        push @keys, $_;
        push @values, $data->{$_};
    };
    return unless @keys;

    # TODO should use sql default instead?
    if (!defined $data->{created}) {
        push @keys, "created";
        push @values, time;
    };
    my $into = join ",", @keys;
    my $quest = join ",", ("?") x @keys;

    my $sth = $self->dbh->prepare_cached( "INSERT INTO $table($into) VALUES ($quest)");
    $sth->execute( @values );

    # if key unknown, just inform about successful insert
    return 1 unless $key;

    my $id = $data->{$key} || $self->dbh->last_insert_id("", "", $table, $key);
    return $id;
};

=head2 save_any( table, id_fields, \%data )

UPDATE data in table with id = value of id_field (required).

Returns value of id_field.

=cut


sub update_any {
    my ($self, $table, $key, $data) = @_;

    my $id = $data->{$key};
    die "Cannot update without id"
        unless defined $id;

    my (@keys, @values);
    foreach (keys %$data) {
        defined $data->{$_} or next;
        $_ eq $key and next;
        push @keys, "$_=?";
        push @values, $data->{$_};
    };
    return unless @keys;

    my $set = join ",", @keys;

    my $sth = $self->dbh->prepare_cached(
        "UPDATE $table SET $set WHERE $key = ?" );
    $sth->execute( @values, $id );

    return $id;
};

# AUXILIARY STUFF

sub _pairs {
    my @ret;
    while (@_) {
        push @ret, [shift, shift];
    };
    return \@ret;
};

1;
