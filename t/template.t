#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Template;
use File::Find;
use File::Basename qw(basename dirname);

my $tpl = dirname(__FILE__)."/../tpl";

my @files = @ARGV;
my @fail;

@files or find( sub {
    -f $_
        and /\.html$/
        and push @files, $File::Find::name;
}, $tpl );

note "Testing tempates: @files";

tpl_ok($_) for @files;

diag "Failed templates: @fail"
    if @fail;

done_testing;

sub tpl_ok {
    my $file = shift;

    $file =~ s#.*/tpl/##;

    my $tt = Template->new(
        INCLUDE_PATH => $tpl,
        RELATIVE     => 1,
        FILTERS      => {
            int    => sub { 1 },
            time   => sub { '1h' },
            render => sub { 'text' },
        },
    );
    my $output;

    my $data = {
        DATE => sub {},
    };

    if (!ok ($tt->process( $file, $data, \$output ), "Template correct $file") ) {
        diag "Error in template $file: ".$tt->error;
        push @fail, $file;
        return 0;
    };

    # TODO check html validity

    return 1;
};

