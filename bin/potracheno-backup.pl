#!/usr/bin/env perl

use strict;
use warnings;
use JSON::XS;
use Getopt::Long;
use File::Basename qw(dirname);

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib";
use App::Its::Potracheno::Model;

my $root;
my $config;
my $todo;
my $dry_run;
GetOptions(
    "root=s" => \$root,
    "config=s" => \$config,
    "dump" => sub { $todo = "dump" },
    "restore" => sub { $todo = "restore" },
    "dry-run" => \$dry_run,
    help => \&usage,
) or die "Bad options, see $0 --help";

sub usage {
    print <<"USAGE"; exit 0;
Usage: $0 [options] [dumpfile]
Options may include:
    --config - config file (required)
    --dump - dump Potracheno database
    --restore - restore Potracheno into an empty database
    Exactly ONE of --dump and --restore must be specified
    --root - project directory ( default: where config is )
    --help - this message
USAGE
};

usage() unless $todo;
my $file = shift;

die "Config required (--config?)"
    unless $config;

$root ||= dirname( $config );

my $model = App::Its::Potracheno::Model->new(
    ROOT        => $root,
    config_file => $config,
);

my $codec = JSON::XS->new;

if ($todo eq "dump") {
    my $fd;
    if (defined $file and $file ne '-') {
        open $fd, ">", $file
            or die "Failed to open(w) $file: $!";
    } else {
        $file = "STDOUT";
        $fd = \*STDOUT;
    };

    warn "Loading DB into memory...\n";
    my $dump = $model->dump();

    foreach my $t( keys %$dump ) {
        warn "Dumping table $t into $file...\n";
        foreach my $row( @{ $dump->{$t} } ) {
            print $fd "$t: ".$codec->encode($row)."\n"
                or die "Failed to write to $file: $!";
        };
        warn "Done table $t\n";
    };
    close $fd
        or die "Failed to sync $file: $!";
    warn "Done dump to $file\n";
} elsif ($todo eq "restore") {
    my $fd;
    if (defined $file and $file ne '-') {
        open $fd, "<", $file
            or die "Failed to open(r) $file: $!";
    } else {
        $file = "STDIN";
        $fd = \*STDIN;
    };

    warn "Loading $file into memory...\n";
    my %dump;
    while (<$fd>) {
        /^\s*#/ and next;
        /^\s*(\w+)\s*:\s*(\{.*\})\s*$/s
            or die "Wrong dump file format in $file";
        my $data = decode_json($2);

        # HACK for v.0.10
        # rename closed 0 => 100
        $data->{status_id} = 100
            if defined $data->{status_id} and $data->{status_id} eq '0';

        push @{ $dump{$1} }, $data;
    };

    warn "Dump has table $_\n" for keys %dump;
    warn "Dump file $file ok\n";
    if ($dry_run) {
        exit 0;
    };
    warn "Restoring DB from memory...\n";
    $model->restore(\%dump);
    warn "Done restore from $file\n";
} else {
    die "Unknown action $todo (possible bug, please contact author)";
};

