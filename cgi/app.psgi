#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = 0.01;

use URI::Escape;
use Data::Dumper;

use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib "$Bin/../lib";
use MVC::Neaf;
use Potracheno::Model;

# Will consume config later
my $model = Potracheno::Model->new;

MVC::Neaf->load_view( TT => TT =>
    INCLUDE_PATH => "$Bin/../tpl",
    PRE_PROCESS  => "common_head.tt",
    POST_PROCESS => "common_foot.tt",
)->render({ -template => \"\n\ntest\n\n" });

MVC::Neaf->set_default( HTML => \&HTML, URI => \&URI, copyright_by => "Lodin" );

# fetch usr
# model.add article
# returnto view
MVC::Neaf->route( post => sub {
    my $req = shift;

    if ( $req->method ne 'POST' ) {
        return {
            -template => "post.html",
            title => "Submit new article",
        };
    };

    # Switch to form?
    my $username = $req->param( user => qr/\w+/ );
    my $summary  = $req->param( summary => qr/\S.+\S/ );
    my $body     = $req->param( body => qr/.*\S.+/ );

    die 422 unless $username and $summary and $body;

    my $user = $model->get_user( name => $username );
    die 403 unless $user; # TODO take to login page instead

    my $id = $model->add_article( user => $user, summary => $summary, body => $body );
    $req->redirect( "/article/$id" );
} );


MVC::Neaf->route( article => sub {
    my $req = shift;

    my $id = $req->path_info =~ /(\d+)/ ? $1 : $req->param ( id => '\d+' );
    die 422 unless $id;

    my $data = $model->get_article( id => $id );
    die 404 unless $data;

    warn Dumper($data);

    return {
        -template => "article.html",
        title => "#$data->{id} - $data->{summary}",
        %$data,
    };
} );

# fetch usr
# model. add time
# return to view
MVC::Neaf->route( addtime => sub {

} );

my %replace = qw( & &amp; < &gt; > &gt; " &qout; );
my $bad_chars = join "", map { quotemeta $_ } keys %replace;
$bad_chars = qr/([$bad_chars])/;

sub HTML {
    my $str = shift;
    $str =~ s/$bad_chars/$replace{$1}/g;
    return $str;
};

sub URI {
    my $str = shift;
    return uri_escape_utf8($str);
};

MVC::Neaf->run();
