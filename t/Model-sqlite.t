#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use File::Temp qw(tempfile);
use FindBin qw($Bin);
use DBI;

use Potracheno::Model;

my $spec = "$Bin/../sql/potracheno.sqlite.sql";

my $sql = do {
    open (my $fd, "<", $spec)
        or die "Failed to load sqlite schema $spec: $!";
    local $/;
    <$fd>
};

my (undef, $dbfile) = tempfile;
my $fail;
$SIG{__DIE__} = sub { $fail++ };
END {
    if ($fail) {
        diag "Tests failed, db available at $dbfile"
    } else {
        unlink $dbfile;
    };
};

my $db = "dbi:SQLite:dbname=$dbfile";
my $dbh = DBI->connect( $db, '', '', { RaiseError => 1 } );

$dbh->do( $_ ) for split /;/, $sql; # this autodies
$dbh->disconnect;

my $model = Potracheno::Model->new(
    config => { db => { handle => $db }},
);

# Huh, let the tests begin
note "TESTING USER";

my $user = $model->add_user( "Foo", "secret" );

is ($user, 1, "1st user on a clean db" );

$user = $model->add_user( "Bar", "secret" );

is ($user, 2, "2nd user on a clean db" );

$user = $model->load_user( name => "Foo" );
is ($user->{user_id}, 1, "Fetching 1st user again" );
is ($user->{name}, "Foo", "Input round trip(3)" );

note explain $user;

$model->add_user( "Commenter", "secret" );
$model->add_user( "Solver", "secret" );

note "TESTING ARTICLE";

my $id = $model->add_issue( body => "explanation", summary => "summary"
    , user => $user );

my $art = $model->get_issue( id => $id );

is ($art->{author}, "Foo", "Author as expected");
is ($art->{body}, "explanation", "Round-trip - body");
is ($art->{summary}, "summary", "Round-trip - summary");
is ($art->{time_spent}, 0, "0 time spent");

note explain $art;

note "TESTING TIME";

$model->log_activity( issue_id => $art->{issue_id}, user_id => 1, time => "1s" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 2, time => "2s" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 3, note => "comment" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 3 );
    # this should appear nowhere
$model->log_activity( issue_id => $art->{issue_id}, user_id => 4, note => "solution", solve_time => "1h" );

$art = $model->get_issue( id => $id );
is ($art->{time_spent}, "3s", "3 time spent");

my $comments = $model->get_comments;

foreach my $extra( qw(created activity_id) ) {
    foreach (@$comments) {
        (delete $_->{$extra}) =~ /^\d+$/
            or die "Bad format of $extra, must be natural number";
    };
};
@$comments = sort {
    $a->{user_id} <=> $b->{user_id}
} @$comments;
is_deeply( $comments, [
    { user_id => 1, note => undef, user_name => "Foo", issue_id => 1,
         seconds => 1, time => "1s", solve_time => 0, solve_time_s => undef },
    { user_id => 2, note => undef, user_name => "Bar", issue_id => 1,
         seconds => 2, time => "2s", solve_time => 0, solve_time_s => undef },
    { user_id => 3, note => "comment", user_name => "Commenter", issue_id => 1,
         seconds => undef, time => "0", solve_time => 0, solve_time_s => undef },
    { user_id => 4, note => "solution", user_name => "Solver", issue_id => 1,
         seconds => undef, time => "0", solve_time => "1h", solve_time_s => 60*60 },
], "Comments as expected" );

diag "SMOKE-TESTING SEARCH";

my $results = $model->search( terms => [ "expl" ] );

note explain $results;
is (ref $results, 'ARRAY', "Got array");
is (scalar @$results, 1, "Got 1 element");
is (scalar (grep { ref $_ ne 'HASH' } @$results), 0
    , "All results in array are hashes");

diag "SMOKE-TESTING REPORT";

my $rep = $model->report;
is (ref $rep, 'ARRAY', "Got array");
is (scalar @$rep, 1, "Got 1 element");
is (scalar (grep { ref $_ ne 'HASH' } @$rep)
    , 0, "All results in array are hashes");

note explain $rep;

done_testing;
