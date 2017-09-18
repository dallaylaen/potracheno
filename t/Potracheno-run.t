#!perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use DBI;

BEGIN { note "Neaf loading..." };
use MVC::Neaf qw(:sugar);
BEGIN { note "App loading..." };
use App::Its::Potracheno;
note "Preparing test data...";

my (undef, $dbfile) = tempfile( SUFFIX => 'sqlite', UNLINK => 1 );

my %min_config = (
    db       => { handle => "dbi:SQLite:$dbfile" },
    status   => { 1 => "open", 2 => "closed " },
);

my $dbh = DBI->connect($min_config{db}{handle}, '', '', { RaiseError => 1 });

my $schema = get_schema_sqlite();

foreach my $stm( split /;/, $schema ) {
    $dbh->do( $stm );
};

note "Routes loading...";
is ref run(\%min_config), "CODE", "A codefer was returned";
note "LOADED POTRACHENO";

note "MAKING REQUESTS";

my ($status, $head, $content);
($status, $head, $content) = neaf->run_test("/");
is $status, 200, "Root present";
like $content, qr#<title>#, "Something like html inside";

($status, $head, $content) = neaf->run_test("/update/post", method => 'POST');

is $status, 403, "Post new issue w/o auth forbidden";

done_testing;
