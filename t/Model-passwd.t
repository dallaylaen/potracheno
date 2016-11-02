#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use App::Its::Potracheno::Model;

my $hash = App::Its::Potracheno::Model->make_pass( "salt", "secret" );
unlike ($hash, qr(secret), "secret is secret");
like ($hash, qr(salt), "salt is retained");
is (App::Its::Potracheno::Model->make_pass( $hash, "secret" ), $hash, "Can auth" );
note $hash;

done_testing;
