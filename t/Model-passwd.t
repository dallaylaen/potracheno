#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use App::Its::Wasted::Model;

my $hash = App::Its::Wasted::Model->make_pass( "salt", "secret" );
unlike ($hash, qr(secret), "secret is secret");
like ($hash, qr(salt), "salt is retained");
is (App::Its::Wasted::Model->make_pass( $hash, "secret" ), $hash, "Can auth" );
note $hash;

done_testing;
