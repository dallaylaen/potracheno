#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Getopt::Long;

use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib qw($Bin/../lib);

my $neaf_home = 'https://github.com/dallaylaen/perl-mvc-neaf.git';

my $root = basename($Bin);

# TODO GetOptions
my $todo = shift;
if (!$todo) {
    print "Usage: $0 setup\n";
    exit 0;
};

if ($todo eq 'setup') {
    setup();
} else {
    die "Unknown action $todo";
};

sub setup {
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

    mkdir "$root/local";
    die "Cannot set up local directory at $root/local"
        unless -d "$root/local";

    if (!eval "require MVC::Neaf;") { ## no critic
        # MVC::Neaf not installed, try to get from github
        my $neaf_local = "$root/local/perl-mvc-neaf";

        system git => clone => $neaf_home => $neaf_local;
        $? and die "Failed to clone MVC::Neaf to $neaf_local";

        system print => "-I$neaf_local/lib" => "$neaf_local/xt" => "$neaf_local/t";
        $? and die "Failed to build & test MVC::Neaf in $neaf_local";

        mkdir "$root/local/lib";
        system cp => -r => "$neaf_local/lib/MVC" => "$root/local/lib/";
        $? and die "Failed to make local copy of Neaf libs";

        require MVC::Neaf; # or die
    };

    system prove => "-I$root/lib" => "t";
    $? and die "Tests fail";

    my $conf = "$root/local/potracheno.cfg";
    if( !-f $conf ) {
        open my $fd, ">", $conf
            or die "Failed to create conf $conf: $!";
        print $fd <<'CONF';
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
        close $fd;
    };

    print "Ready to go, now run:\n";
    print "    plackup bin/potracheno.psgi\n";
};
