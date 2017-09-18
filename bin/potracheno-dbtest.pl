#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib";
use App::Its::Potracheno::Model;

my $conf = shift;

if (!$conf) {
    plan skip_all => "Usage: $0 <config.file>";
    exit;
};

my $root = dirname($conf);

my $model = App::Its::Potracheno::Model->new( ROOT => $root, config_file => $conf );

ok ( $model->dbh, "DBH exists" );

ok ( $model->get_status(1), "Open status exists" );
ok ( $model->get_status(100), "Closed status exists" );

eval {
    $model->login( "foo", "bar" );
};
is ( $@, '', "login doesn't die" );

eval {
    $model->get_issue( id => 1 );
};
is ( $@, '', "get_issue doesn't die" );

eval {
    $model->get_time( user_id => -1, issue_id => -1 );
};
is ( $@, '', "get_time doesn't die" );

eval {
    $model->get_comments( user_id => -1, issue_id => -1 );
};
is ( $@, '', "get_comments doesn't die");

eval {
    $model->load_session( 'xxxxxxxxxxxxxxx' );
};
is ( $@, '', "load_session doesn't die" );

eval {
    $model->search( terms => [ 'xxxxxxxxxxxxxxxxxxxxxx' ] );
};
is ( $@, '', "search doesn't die" );

eval {
    $model->get_watch( user_id => 100500, issue_id => 42137 );
};
is ( $@, '', "get_watch doesn't die" );

eval {
    $model->watch_feed( user_id => 100500, issue_id => 42137 );
};
is ( $@, '', "watch_feed doesn't die" );

eval {
    $model->get_stats_total( );
};
is ( $@, '', "get_stats_total doesn't die" );

eval {
    $model->get_tag_stats(  );
};
is ( $@, '', "get_tag_stats doesn't die" );

diag "Tested DB at ", $model->{config}{db}{handle};

done_testing;
