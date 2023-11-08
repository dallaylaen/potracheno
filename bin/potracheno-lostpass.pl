#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use POSIX qw(strftime);
use File::Basename qw(dirname);

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib";
use App::Its::Wasted qw(silo);

my $root;
my $config;
GetOptions (
    "help"     => \&usage,
    "root=s"   => \$root,
    "config=s" => \$config,
) or die "Bad options, see $0 --help";

sub usage {
    print <<"USAGE"; exit 0;
Usage: $0 <base_url>
List ALL pending password reset links.
Options may include:
    --root - root of the application (defaults to parent dir)
    --config - config file location (defaults to local/potracheno.cfg)
    --help - this message
USAGE
};

usage() unless @ARGV;

my $base_url = shift;

my $model = silo->model;

my $list = $model->list_reset;

foreach (sort { $a->{name} cmp $b->{name} } @$list) {
    my $when = strftime("%Y-%m-%d %H:%M:%S", localtime $_->{expires});
    print "$_->{name} $base_url/auth/setpass/$_->{reset_key} expires on $when\n";
};


