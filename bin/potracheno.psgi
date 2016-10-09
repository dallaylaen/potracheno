#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = 0.0601;

use URI::Escape;
use Data::Dumper;
use POSIX qw(strftime);

use File::Basename qw(dirname);
use lib dirname(__FILE__)."/../lib", dirname(__FILE__)."/../local/lib";
use MVC::Neaf 0.09;
use MVC::Neaf qw(neaf_err);
use MVC::Neaf::X::Form;
use Potracheno::Model;

my $Bin = dirname(__FILE__); # FindBin doesn't seem to work well under plackup

my $conf = {
    db => {
        handle => "dbi:SQLite:dbname=$Bin/../local/potracheno.sqlite",
    },
};

# Will consume config later
my $model = Potracheno::Model->new(
    config => $conf, # fallback value
    config_file => "$Bin/../local/potracheno.cfg",
    ROOT   => "$Bin/..",
);

MVC::Neaf->load_view( TT => TT =>
    INCLUDE_PATH => "$Bin/../tpl",
    PRE_PROCESS  => "common_head.html",
    POST_PROCESS => "common_foot.html",
    EVAL_PERL => 1,
)->render({ -template => \"\n\ntest\n\n" });

MVC::Neaf->set_default( DATE => \&DATE, version => "$VERSION/".Potracheno::Model->VERSION );

MVC::Neaf->set_session_handler( engine => $model, view_as => 'session' );

MVC::Neaf->static( i => "$Bin/../html/i" );
MVC::Neaf->static( 'favicon.ico' => "$Bin/../html/i/icon.png" );

MVC::Neaf->route( login => sub {
    my $req = shift;

    my $name = $req->param( name => '\w+' );
    my $pass = $req->param( pass => '.+' );
    my $data;
    my $wrong;
    if ($req->method eq 'POST' and $name and $pass) {
        $data = $model->login( $name, $pass );
        $wrong = "Login failed!";
    };
    if ($data) {
        warn "LOGIN SUCCESSFUL!!!";
        $req->save_session( $data );
        $req->redirect( $req->param( return_to => '/.*', '/') );
    };

    return {
        -template => 'login.html',
        wrong => $wrong,
        name => $name,
    };
} );

MVC::Neaf->route( logout => sub {
    my $req = shift;

    $req->delete_session;
    $req->redirect( $req->referer || '/' );
});

MVC::Neaf->route( register => sub {
    my $req = shift;

    my $user = $req->param( user => '\w+' );
    if ($req->method eq 'POST') {
        eval {
            $user or die "FORM: [User must be nonempty alphanumeric]";
            my $pass  = $req->param( pass  => '.+' );
            $pass or die "FORM: [Password empty]";
            my $pass2 = $req->param( pass2 => '.+' );
            $pass eq $pass2 or die "FORM: [Passwords do not match]";

            my $id = $model->add_user( $user, $pass );
            $id   or die "FORM: [Username '$user' already taken]";

            $req->save_session( { user_id => $id } );
            $req->redirect("/");
        };
        neaf_err($@);
    };

    my ($wrong) = $@ =~ /^FORM:\s*\[(.*)\]/;

    return {
        -template => 'register.html',
        title => "Register new user",
        user => $user,
        wrong => $wrong,
    };
});

MVC::Neaf->route( edit_user => sub {
    my $req = shift;

    $req->redirect("/login") unless $req->session->{user_id};
    my $details = $model->load_user( user_id => $req->session->{user_id} );

    if ($req->method eq 'POST') {
        # form submitted
        my $oldpass = $req->param( oldpass => '.+' );
        $model->check_pass( $details->{password}, $oldpass )
            or die 403; # TODO show form again

        my $newpass = $req->param( pass  => '.+' );
        my $pass2   = $req->param( pass2 => '.+' );
        if ($newpass) {
            $newpass eq $pass2 or die "422"; # TODO show form again
            $details->{pass} = $newpass;
        };

        $model->save_user( $details );
        $req->redirect( "/user/$details->{user_id}" );
    };

    return {
        -template => 'register.html',
        title => "Edit user $details->{name}",
        details => $details,
    };
});

# post new issue - validator
my $val_post = MVC::Neaf::X::Form->new({
    summary => [ required => qr/\S.+\S/ ],
    body    => [ required => qr/.*\S.+/s ],
});
MVC::Neaf->route( post => sub {
    my $req = shift;

    my $user = $req->session;
    my $form = $req->form( $val_post );
    $user->{user_id} or $form->error( user => "Please log in to post issues" );

    if ( $req->method eq 'POST' and $form->is_valid ) {
        my $id = $model->add_issue( user => $user, %{ $form->data });
        $req->redirect( "/issue/$id" );
    };

    return {
        -template => "post.html",
        title     => "Submit new issue",
        form      => $form,
        issue     => $model->render_issue($form->data),
    };
} );

MVC::Neaf->route( issue => sub {
    my $req = shift;

    my $id = $req->path_info =~ /(\d+)/ ? $1 : $req->param ( id => '\d+' );
    my $show_all = $req->param(all => 1);
    die 422 unless $id;

    my $data = $model->get_issue( id => $id );
    die 404 unless $data->{issue_id};
    warn Dumper($data);

    my $comments = $model->get_comments(
        issue_id => $id, sort => '+created', text_only => !$show_all );

    return {
        -template => "issue.html",
        title => "#$data->{issue_id} - $data->{summary}",
        issue => $model->render_issue($data),
        comments => $comments,
        statuses => $model->get_status_pairs,
    };
} );

MVC::Neaf->route( search => sub {
    my $req = shift;

    my $q = $req->param(q => '.*');

    my @term = $q =~ /([\w*?]+)/g;

    my $result = $model->search(terms => \@term);

    return {
        -template => 'search.html',
        title => "Search results for @term",
        results => $result,
        q => $q,
        terms => \@term,
    };
} );

# fetch usr
# model. add time
# return to view
MVC::Neaf->route( addtime => sub {
    my $req = shift;

    my $user = $req->session;
    die 403 unless $user;

    # TODO use form!!!!
    my $issue_id = $req->param( issue_id => qr/\d+/ );
    my $seconds  = $req->param( seconds => qr/.+/, 0 );
    my $note     = $req->param( note => qr/.*\S.+/s );
    my $status_id = $req->param( status_id => qr/\d+/, undef );
    my $type     = $req->param( type => qr/fix/ );

    die 422 unless $issue_id;
    if (defined $status_id) {
        defined $model->get_status($status_id)
            or die 422;
    };

    $model->log_activity( issue_id => $issue_id, user_id => $user->{user_id}
        , ($type eq 'fix' ? 'solve_time' : 'time') => $seconds
        , note => $note, status_id => $status_id)
        if $seconds or $note or $status_id;

    $req->redirect( "/issue/$issue_id" );
}, method => "POST" );

MVC::Neaf->route( user => sub {
    my $req = shift;

    my $id = $req->param( user_id => '\d+', $req->path_info =~ /(\d+)/ );
    my $data = $model->load_user ( user_id => $id );
    die 404 unless $data->{user_id};

    my $comments = $model->get_comments( user_id => $id, sort => '-created' );
    return {
        -template => 'user.html',
        title => "$data->{name} - user details",
        user => $data,
        comments => $comments,
    };
});

my $val_report = MVC::Neaf::X::Form->new({
    order_by     => '\w+',
    order_dir    => 'ASC|DESC',
    date_from    => '\d\d\d\d-\d\d-\d\d',
    date_to      => '\d\d\d\d-\d\d-\d\d',
    has_solution => '[01]',
    status       => '\d+',
    status_not   => '.+',
});
MVC::Neaf->route( report => sub {
    my $req = shift;

    my $form = $req->form( $val_report );

    $form->data->{status_not} = !!$form->data->{status_not};

    my $data = [];
    $data = $model->report( %{ $form->data } )
        if $form->is_valid;

    return {
        -template => 'report.html',
        title => "Issue report",
        table_data => $data,
        order_options => $model->report_order_options,
        status_pairs => $model->get_status_pairs,
        form => $form,
    };
});

MVC::Neaf->route( "/" => sub {
    my $req = shift;

    # this is main page ONLY
    die 404 if $req->path_info gt '/';

    return {
        title => "Potracheno - wasted time tracker",
        -template => "main.html",
    };
} );

my %replace = qw( & &amp; < &gt; > &gt; " &qout; );
my $bad_chars = join "", map { quotemeta $_ } keys %replace;
$bad_chars = qr/([$bad_chars])/;

# TODO move to model OR view
sub DATE {
    my $time = shift;
    return strftime("%Y-%m-%d %H:%M:%S", localtime($time));
};

MVC::Neaf->run();
