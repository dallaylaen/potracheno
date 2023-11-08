#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/local/lib";

my $neaf_home = 'https://github.com/dallaylaen/perl-mvc-neaf.git';

my $check;
my $write;
GetOptions(
    "install"   => \$write,
    "check"     => \$check,
    "help"      => \&usage,
    "neaf=s"      => \$neaf_home,
) or die "Bad usage, see $0 --help";

sub usage {
    print <<"USAGE"; exit 0;
Usage:
    $0 [options] --check     # check dependencies & prerequisites
    $0 [options] --install   # also create files & directories
The following checks are performed:
 *     check CPAN dependencies
 *     check/create ./local
 * (w) install MVC::Neaf into local/, if absent
 *     run tests from t/
 * (w) create local/potracheno.cfg and local/potracheno.sqlite, if absent
 *     check that DB in potracheno.cfg is suitable for running
Only local directory is affected.
USAGE
};

if ($check || $write) {
    setup($Bin, $write);
} else {
    usage();
};

sub setup {
    my ($root, $write) = @_;
    check_deps();

    mkdir "$root/local" if $write;
    die "Cannot access local directory at $root/local"
        unless -d "$root/local";

    run_tests( $root );

    my $conf = "$root/local/potracheno.cfg";

    if( !-f $conf ) {
        die "Config not found at $conf"
            if !$write;
        create_config( $conf );

        my $sqlite = "$root/local/potracheno.sqlite";
        create_sqlite( $sqlite )
            unless -f $sqlite;
    };

    check_db( $root, $conf );

    print "Ready to go, now run:\n";
    print "    plackup bin/potracheno.psgi\n";
};

sub check_deps {
    my @modlist = qw(
        Data::Dumper DBI DBD::SQLite Digest::MD5
        File::ShareDir
        Getopt::Long
        JSON::XS
        lib::relative
        LWP::UserAgent
        Moo MVC::Neaf
        Resource::Silo
        Test::More Text::Markdown Time::Local
    );

    my @missing = grep { !eval "require $_;" } @modlist; ## no critic
    if (@missing) {
        die "Required modules missing, please install them: @missing";
    };
};

sub create_config {
    my $conf = shift;

    open my $fd, ">", $conf
        or die "Failed to create conf $conf: $!";
    print $fd <<'CONF' or die "Failed to write config $conf: $!";
# default config
[db]
handle = "dbi:SQLite:$(ROOT)/potracheno.sqlite"

# handle = "dbi:mysql:database=potracheno;host=localhost"
# user = 'my_user'
# pass = 'my_pass'

[status]
1   = Open
70  = "Solution underway"
100 = Closed

[security]
member_only = 0

[update]
interval = 86400
CONF
    close $fd or die "Failed to sync config $conf: $!";
};

sub check_db {
    my ($root, $conf) = @_;
    system perl => "$root/bin/potracheno-dbtest.pl" => $conf;
    $? and die "DB check failed, adjust config or set up db";
};

sub run_tests {
    my $root = shift;
    system prove => "-I$root/lib" => "-I$root/local/lib" => -r => "$root/t";
    $? and die "Tests fail";
};

sub create_sqlite {
    my ( $sqlite ) = @_;

    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite"
        , '', '', { RaiseError => 1} );

    require App::Its::Wasted::Model;

    my $sql = App::Its::Wasted::Model->get_schema_sqlite;

    foreach (split /;/, $sql) {
        $dbh->do($_);
    };
};

