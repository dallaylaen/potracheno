#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use App::Its::Wasted::Model;

my $model = App::Its::Wasted::Model->new( dbh => {} );

my $text = $model->render_text(<<"MD");
 * this
 * is
 * list

*italic*

**bold**

<script lang="javascript">alert("pwned")</script>

<code>rm -rf /</code>

<plain><code></code> **non-bold**</plain>

MD

like ($text, qr#<li>list</li>#i, "List ok");
like ($text, qr#<(i|em)>italic</\1>#i, "Italic ok");
like ($text, qr#<(b|strong)>bold</\1>#i, "Bold ok");
like ($text, qr#<pre.*>rm -rf /</pre>#, "Pre ok");
like ($text, qr#&lt;code&gt;.*\*\*non-bold\*\*#, "Plain ok");

# XSS no more
unlike ($text, qr#<script#i, "No script");

done_testing;
