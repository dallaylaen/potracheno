#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib qq($Bin/../lib);

my $neaf_home = 'https://github.com/dallaylaen/perl-mvc-neaf.git';

my $doit;
my $readonly;
GetOptions(
    "doit"      => \$doit,
    "readonly"  => \$readonly,
    "help"      => \&usage,
) or die "Bad usage, see $0 --help";

sub usage {
    print <<"USAGE"; exit 0;
Usage: $0 [options] --doit
Will check prerequisites, try install local copy of MVC::Neaf,
and do some extra checks. Options may include:
    --readonly - don't create files/directories
USAGE
};

if ($doit) {
    setup(dirname($Bin), $readonly);
};

sub setup {
    my ($root, $readonly) = @_;
    check_deps();

    mkdir "$root/local" unless $readonly;
    die "Cannot access local directory at $root/local"
        unless -d "$root/local";

    if ($readonly) {
        require MVC::Neaf;
    } else {
        check_neaf( $root, "$root/local/perl-mvc-neaf", $neaf_home );
    };
    run_tests( $root );

    my $conf = "$root/local/potracheno.cfg";

    if( !-f $conf ) {
        die "Config not found at $conf"
            if $readonly;
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
        Carp
        Data::Dumper DBI DBD::SQLite Digest::MD5
        Encode Errno
        File::Basename File::Find File::Temp FindBin
        Getopt::Long
        HTTP::Headers
        JSON::XS
        LWP::UserAgent
        Plack::Request POSIX
        Scalar::Util Sys::Hostname
        Template Test::More Time::HiRes
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

sub check_neaf {
    my ($root, $neaf_local, $neaf_home) = @_;

    # already there - nothing to do
    return if eval { require MVC::Neaf; };

    # MVC::Neaf not installed, try to get from github
    system git => clone => $neaf_home => $neaf_local
        unless -d $neaf_local;
    $? and die "Failed to clone MVC::Neaf to $neaf_local";

    system prove => "-I$neaf_local/lib" => "$neaf_local/t";
    $? and die "Failed to build & test MVC::Neaf in $neaf_local";

    mkdir "$root/local/lib";
    system cp => -r => "$neaf_local/lib/MVC" => "$root/local/lib/";
    $? and die "Failed to make local copy of Neaf libs";

    require MVC::Neaf; # or die
    print "check_heaf() done\n";
};

sub run_tests {
    my $root = shift;
    system prove => "-I$root/lib" => "$root/t";
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

