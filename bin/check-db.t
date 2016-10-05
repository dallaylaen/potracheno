#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib";
use Potracheno::Model;

my $root = "$Bin/..";
my $conf = shift;

if (!$conf) {
    plan skip_all => "Usage: $0 <config.file>";
    exit;
};

my $model = Potracheno::Model->new( ROOT => $root, config_file => $conf );

ok ( $model->dbh, "DBH exists" );

ok ( $model->get_status(0), "Closed status exists" );
ok ( $model->get_status(1), "Open status exists" );

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

diag "Tested DB at ", $model->{config}{db}{handle};

done_testing;
