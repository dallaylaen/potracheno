#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Potracheno::Config;

note "POSITIVE CASES";
my $conf;

$conf = Potracheno::Config->load_config(\"foo=http://bar.com/baz?xxx=42");
is_deeply( $conf, { global => { foo => "http://bar.com/baz?xxx=42" } }
    , "Bareword")
    or note explain $conf;

$conf = Potracheno::Config->load_config(\"[foo]\nbar=42;\n\n");
is_deeply( $conf, { foo => { bar => 42 } }, "Semicolon, section");

$conf = Potracheno::Config->load_config(\"foo='bar\\'\\\n    baz'");
is_deeply( $conf, { global => { foo => "bar'baz" } }, "Quotes, cont, escape");

$conf = Potracheno::Config->load_config(\'json = { "x":42, "y":[] }');
is_deeply( $conf, { global => { json => { x => 42, y => [] } } }
    , "JSON" );

$conf = Potracheno::Config->load_config(\'    # this is a comment');
is_deeply( $conf, {}, "Comment");

$conf = Potracheno::Config->load_config(\"[x]\nfoo=42\nbar=\"\$(x#foo)0\"");
is_deeply( $conf, { x => { foo => 42, bar => 420 } }, "Interpolation");

$conf = Potracheno::Config->load_config(\"log='\$(ROOT)/error.log'"
    , ROOT => "foo" );
is_deeply( $conf, { global => { ROOT => "foo", log => "foo/error.log" } }
    , "Interpolation + default subst");

note "NEGATIVE CASES";

eval {
    Potracheno::Config->load_config(\"foo = ");
};
note $@;
like ($@, qr/^Potracheno::Config->load_config/, "Exception as planned");

eval {
    Potracheno::Config->load_config(\"5 = 2*2");
};
note $@;
like ($@, qr/^Potracheno::Config->load_config/, "Exception as planned");

eval {
    Potracheno::Config->load_config(\"[");
};
note $@;
like ($@, qr/^Potracheno::Config->load_config/, "Exception as planned");

eval {
    Potracheno::Config->load_config(\"foo=1\nfoo=2");
};
note $@;
like ($@, qr/^Potracheno::Config->load_config/, "Exception as planned");

eval {
    Potracheno::Config->load_config(\"foo='\$(UNKNOWN)'");
};
note $@;
like ($@, qr/^Potracheno::Config->load_config/, "Exception as planned");


done_testing;
