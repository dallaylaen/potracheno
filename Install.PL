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

    if ($write) {
        install_neaf( $root, "$root/local/perl-mvc-neaf", $neaf_home );
    } else {
        # Don't install, just check
        require MVC::Neaf;
    };
    run_tests( $root );

    my $conf = "$root/local/potracheno.cfg";

    if( !-f $conf ) {
        die "Config not found at $conf"
            if !$write;
        create_config( $conf );

        my $sqlite = "$root/local/potracheno.sqlite";
        create_sqlite( $sqlite, "$root/sql/potracheno.sqlite.sql" )
            unless -f $sqlite;
    };

    check_db( $root, $conf );

    print "Ready to go, now run:\n";
    print "    plackup bin/potracheno.psgi\n";
};

sub check_deps {
    my @modlist = qw(
        Carp CGI
        Data::Dumper DBI DBD::SQLite Digest::MD5
        Encode Errno
        File::Basename File::Find File::Temp FindBin
        Getopt::Long
        HTTP::Headers
        JSON::XS
        LWP::UserAgent
        Plack::Request POSIX
        Scalar::Util Sys::Hostname
        Template Test::More Text::Markdown Time::HiRes
        URI::Escape
        overload parent
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
handle = "dbi:SQLite:$(ROOT)/local/potracheno.sqlite"

# handle = "dbi:mysql:database=potracheno;host=localhost"
# user = 'my_user'
# pass = 'my_pass'

[status]
0 = Closed
1 = Open
2 = "Solution underway"
CONF
    close $fd or die "Failed to sync config $conf: $!";
};

sub check_db {
    my ($root, $conf) = @_;
    system perl => "$root/bin/check-db.t" => $conf;
    $? and die "DB check failed, adjust config or set up db";
};

sub install_neaf {
    my ($root, $neaf_local, $neaf_home) = @_;

    # already there - nothing to do
    return if eval { require MVC::Neaf; };

    # MVC::Neaf not installed, try to get from github
    system git => clone => $neaf_home => $neaf_local
        unless -d $neaf_local;
    $? and die "Failed to clone MVC::Neaf to $neaf_local";

    system prove => "-I$neaf_local/lib" => -r => "$neaf_local/t";
    $? and die "Failed to build & test MVC::Neaf in $neaf_local";

    mkdir "$root/local/lib";
    system cp => -r => "$neaf_local/lib/MVC" => "$root/local/lib/";
    $? and die "Failed to make local copy of Neaf libs";

    require MVC::Neaf; # or die
    print "check_heaf() done\n";
};

sub run_tests {
    my $root = shift;
    system prove => "-I$root/lib" => "-I$root/local/lib" => -r => "$root/t";
    $? and die "Tests fail";
};

sub create_sqlite {
    my ( $sqlite, $schema ) = @_;

    open (my $fd, "<", $schema)
        or die "Failed t oopen(r) $schema: $!";

    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite"
        , '', '', { RaiseError => 1} );

    local $/ = ';';
    while (<$fd>) {
        $dbh->do($_);
    };
};

