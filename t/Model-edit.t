#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use DBD::SQLite;
use File::Temp qw(tempfile);

use App::Its::Potracheno::Model;

# copy-paste: t/Model-sqlite.t
my (undef, $dbfile) = tempfile( SUFFIX => '.potr.sqlite' );
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
# end copy-paste: t/Model-sqlite.t

my $model = App::Its::Potracheno::Model->new( dbh => $dbh );

$dbh->do( <<"SQL" );
CREATE TABLE test (
    test_id INTEGER PRIMARY KEY autoincrement,
    user_id INTEGER,
    name VARCHAR(80),
    created INT NOT NULL
);
SQL

my $id = $model->save_any(
    test => test_id => { user_id => 137, name => 'foo' } );

is ($id, 1, "1st item created");

eval {
    local $SIG{__DIE__};
    $model->edit_record(
        table => 'test',
        condition => { name => 'food' },
        permission => { user_id => 42 },
        data => { name => 'bard' },
    );
};
like $@, qr/^404/, "Not found"
    or $fail++;

eval {
    local $SIG{__DIE__};
    $model->edit_record(
        table => 'test',
        condition => { name => 'foo' },
        permission => { user_id => 42 },
        data => { name => 'bar' },
    );
};
like $@, qr/^403/, "Forbidden"
    or $fail++;

my ($i, $data);

$data = $model->_run_query('SELECT * FROM test', [], {});
delete $_->{created} for @$data;
is_deeply ( $data
    , [{ name => 'foo', user_id => 137, test_id => 1 }]
    , "Data round trip ".++$i )
        or diag explain $data;

eval {
    local $SIG{__DIE__};
    $model->edit_record(
        table => 'test',
        condition => { name => 'foo' },
        permission => { user_id => 137 },
        data => { name => 'bar' },
    );
};
like $@, qr/^$/, "Allowed"
    or $fail++;

$data = $model->_run_query('SELECT * FROM test', [], {});
delete $_->{created} for @$data;
is_deeply ( $data
    , [{ name => 'bar', user_id => 137, test_id => 1 }]
    , "Data round trip ".++$i )
        or diag explain $data;

done_testing;
