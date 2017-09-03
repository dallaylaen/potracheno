#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use POSIX qw(strftime);

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib";
use App::Its::Potracheno::Model;

my $root   = "$Bin/..";
my $config = "$root/local/potracheno.cfg";
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

my $model = App::Its::Potracheno::Model->new(
    config_file   => $config,
    ROOT          => $root,
);

my $list = $model->list_reset;

foreach (sort { $a->{name} cmp $b->{name} } @$list) {
    my $when = strftime("%Y-%m-%d %H:%M:%S", localtime $_->{expires});
    print "$_->{name} $base_url/auth/setpass/$_->{reset_key} expires on $when\n";
};


