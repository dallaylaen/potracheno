#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

# Always prefer local libs if possible
use FindBin qw($Bin);
use lib "$Bin/../local/lib", "$Bin/../lib";
use App::Its::Potracheno::Model;

my $conf;
my %todo;
my $root;
my $config;
GetOptions (
    "help"      => \&usage,
    "root=s"    => \$root,
    "config=s"  => \$config,
    "ban"     => \$todo{ban},
    "unban"   => \$todo{unban},
    "admin"   => \$todo{admin},
    "unadmin" => \$todo{unadmin},
    "list"    => \$todo{list},
) or die "Bad options, see $0 --help";
defined $todo{$_} or delete $todo{$_} for keys %todo;

sub usage {
    print <<"USAGE"; exit 0;
Usage: $0 [options] {--[un]ban|--[un]admin} <user>
List ALL pending password reset links.
Options may include:
    --root - root of the application (defaults to parent dir)
    --config - config file location (defaults to local/potracheno.cfg)
    --help - this message
USAGE
};

usage() unless %todo and @ARGV;

die "Only one action may be specified at a time"
    if scalar keys %todo > 1;

my ($action) = keys %todo;
my $model = App::Its::Potracheno::Model->new(
    config_file => $config, ROOT => $root );

my %ACT = (
    ban => sub { $_[0]->{banned} = 1 },
    unban => sub { $_[0]->{banned} = 0 },
    admin => sub { $_[0]->{admin} = 1 },
    unadmin => sub { $_[0]->{admin} = 0 },
    list => sub {
        print join(
            ":", $_[0]->{user_id}, $_[0]->{name},
            ($_[0]->{admin} ? "admin" : ()),
            ($_[0]->{banned} ? "ban" : ()),
        )."\n";
    },
);

my $fail;
my @done;
foreach my $user( @ARGV ) {
    my $data = $model->load_user( name => $user );
    if (!$data) {
        warn "WARNING $action: no such user $user\n";
        $fail++;
        next;
    };

    $ACT{$action}->($data);
    $model->save_user( $data )
        unless $action eq 'list';
    push @done, $user;
};

print "$action: updated users: @done\n"
    unless $action eq 'list';

exit !!$fail;

