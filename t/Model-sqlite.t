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
    db_handle => $db,
);

# Huh, let the tests begin
note "TESTING USER";

my $user = $model->get_user( name => "Foo" );

is ($user->{user_id}, 1, "1st user on a clean db" );
is ($user->{name}, "Foo", "Input round trip" );

$user = $model->get_user( name => "Bar" );

is ($user->{user_id}, 2, "2nd user on a clean db" );
is ($user->{name}, "Bar", "Input round trip (2)" );

$user = $model->get_user( name => "Foo" );
is ($user->{user_id}, 1, "Fetching 1st user again" );
is ($user->{name}, "Foo", "Input round trip(3)" );

note explain $user;

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

$model->add_time( issue_id => $art->{issue_id}, user_id => 1, time => "1s" );
$model->add_time( issue_id => $art->{issue_id}, user_id => 2, time => "2s" );

$art = $model->get_issue( id => $id );
is ($art->{time_spent}, "3s", "3 time spent");

my $comments = $model->get_comments;

foreach my $extra( qw(posted time_spent_id) ) {
    foreach (@$comments) {
        (delete $_->{$extra}) =~ /^\d+$/
            or die "Bad format of $extra, must be natural number";
    };
};
@$comments = sort { $a->{user_id} <=> $b->{user_id} } @$comments;
is_deeply( $comments, [
    { user_id => 1, note => undef, user_name => "Foo", issue_id => 1, seconds => 1, time => "1s" },
    { user_id => 2, note => undef, user_name => "Bar", issue_id => 1, seconds => 2, time => "2s" },
], "Comments as expected" );

note "TESTING SEARCH";

my $results = $model->search( terms => [ "expl" ] );

note explain $results;

done_testing;
