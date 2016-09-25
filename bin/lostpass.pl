#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Potracheno::Model;

my $root   = "$Bin/..";
my $config = "$root/local/potracheno.cfg";
GetOptions (
    "help"     => \&usage,
    "root=s"   => \$root,
    "config=s" => \$config,
) or die "Bad options, see $0 --help";

sub usage {
    print <<"USAGE"; exit 0;
Usage: $0 <username> <new_password>
Sets temporary password for a user who lost theirs.
Options may include:
    --root - root of the application (defaults to parent dir)
    --confin - config file location (defaults to local/potracheno.cfg)
    --help - this message
USAGE
};

usage() unless @ARGV == 2;

my ($user, $pass) = @ARGV;

my $model = Potracheno::Model->new(
    config_file   => $config,
    ROOT          => $root,
);

my $detail = $model->load_user( name => $user );
$detail or die "Username '$user' not found in DB";

print "# Setting password for user #$detail->{user_id} '$user'...\n";

$detail->{pass} = $pass;
$model->save_user($detail);

print "# Done\n";

