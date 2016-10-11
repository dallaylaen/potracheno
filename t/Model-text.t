#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Potracheno::Model;

my $model = Potracheno::Model->new( dbh => {} );

my $text = $model->render_text(<<"MD");
 * this
 * is
 * list

*italic*

**bold**

<script lang="javascript">alert("pwned")</script>

MD

like ($text, qr#<li>list</li>#i, "List ok");
like ($text, qr#<(i|em)>italic</\1>#i, "Italic ok");
like ($text, qr#<(b|strong)>bold</\1>#i, "Bold ok");

# XSS no more
unlike ($text, qr#<script#i, "No script");

done_testing;
