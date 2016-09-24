#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Potracheno::Model;

my $hash = Potracheno::Model->make_pass( "salt", "secret" );
unlike ($hash, qr(secret), "secret is secret");
like ($hash, qr(salt), "salt is retained");
is (Potracheno::Model->make_pass( $hash, "secret" ), $hash, "Can auth" );
note $hash;

done_testing;
