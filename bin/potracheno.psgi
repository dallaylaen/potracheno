#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = 0.0707;

use URI::Escape;
use Data::Dumper;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);

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
    FILTERS => {
        int  =>    sub { return int $_[0] },
        time =>    sub { return $model->time2human($_[0]) },
        render =>  sub { return $model->render_text($_[0]) },
    },
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
        title => 'Log in',
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
    sign    => '.+',
    create  => '.+',
    issue_id => '\d+',
});
MVC::Neaf->route( post => sub {
    my $req = shift;

    my $user = $req->session;
    my $form = $req->form( $val_post );
    $user->{user_id} or $form->error( user => "Please log in to post issues" );

    $form->data->{sign} ||= '';

    my $sign = $form->is_valid
        ? md5_base64( join "\n\n", $user->{user_id}, $form->data->{summary}
            , $form->data->{body} )
        : '';

    if ($sign ne $form->data->{sign} || !$form->data->{create}) {
        $form->error( preview_mode => 1 );
        $form->raw->{sign} = $sign;
    };

    if ( $req->method eq 'POST' and $form->is_valid ) {
        my $id = $model->save_issue( user => $user, issue => $form->data);
        $req->redirect( "/issue/$id" );
    };

    $form->data->{user_id} = $user->{user_id};
    $form->data->{author}  = $user->{name};
    $form->data->{created} = time;

    return {
        -template => "post.html",
        title     => "Submit new issue",
        form      => $form,
        issue     => $model->render_issue($form->data),
    };
} );

MVC::Neaf->route ( edit_issue => sub {
    my $req = shift;

    my $user = $req->session->{user_id};
    my $id = $req->param( id => '\d+' );

    $user or die 403;
    $id or die 404;

    my $issue = $model->get_issue( id => $id );
    my $form  = $val_post->validate( $issue );

    return {
        -template => 'post.html',
        title     => 'Edit issue',
        form      => $form,
        issue     => $model->render_issue( $issue ),
        post_to   => "/post",
    };
});

MVC::Neaf->route( issue => sub {
    my $req = shift;

    my $id = $req->path_info =~ /(\d+)/ ? $1 : $req->param ( id => '\d+' );
    my $show_all = $req->param(all => 1);
    die 422 unless $id;

    my $data = $model->get_issue( id => $id );
    die 404 unless $data->{issue_id};
    warn Dumper($data);

    my $comments = $model->get_comments(
        issue_id => $id, sort => '+created', text_only => !$show_all);

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
    my $seconds  = $req->param( seconds => qr/.*[^\d.].*/, 0 );
    my $note     = $req->param( note => qr/.*\S.+/s );
    my $status_id = $req->param( status_id => qr/\d+/, undef );
    my $type     = $req->param( type => qr/fix/ );

    die 422 unless $issue_id;
    if (defined $status_id) {
        defined $model->get_status($status_id)
            or die 422;
    };

    if ($seconds or $note or defined $status_id) {
        warn "Time to update: sec=$seconds note=$note st=$status_id";
        $model->log_activity( issue_id => $issue_id, user_id => $user->{user_id}
            , ($type eq 'fix' ? 'solve_time' : 'time') => $seconds
            , note => $note, status_id => $status_id);
    };

    $req->redirect( "/issue/$issue_id" );
}, method => "POST" );

MVC::Neaf->route( user => sub {
    my $req = shift;

    my $id = $req->param( user_id => '\d+', $req->path_info =~ /(\d+)/ );
    my $data = $model->load_user ( user_id => $id );
    die 404 unless $data->{user_id};

    my $comments = $model->get_comments(
        user_id => $id, sort => '-created');
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
    min_a_created    => '\d\d\d\d-\d\d-\d\d',
    max_a_created    => '\d\d\d\d-\d\d-\d\d',
    has_solution => '\d',
    status       => '\d+',
    status_not   => '.+',
    ready        => '.+',
    pi_factor    => '\d+\.?\d*',
    min_time_spent_s => '.+',
    max_time_spent_s => '.+',
    min_estimate => '.+',
    max_estimate => '.+',
    # pagination
    limit        => '\d+',
    start        => '\d+',
    next         => '.+',
    prev         => '.+',
    start_report => '.+',
});
MVC::Neaf->route( report => sub {
    my $req = shift;

    my $form = $req->form( $val_report );

    $form->data->{status_not} = !!$form->data->{status_not};

    $form->data->{limit} ||= 0;
    $form->data->{start} ||= 0;
    if (delete $form->data->{next}) {
        $form->data->{start}+=$form->data->{limit};
        $form->raw->{start}+=$form->data->{limit};
    };
    if (delete $form->data->{prev}) {
        $form->data->{start}-=$form->data->{limit};
        $form->raw->{start}-=$form->data->{limit};
    };
    $form->data->{start} = 0
        if $form->data->{start} < 0 or delete $form->data->{start_report};

    my $data = [];
    my $stat;
    if ($form->is_valid) {
        $data = $model->report( %{ $form->data } );
        $stat = $model->report( %{ $form->data }, count_only => 1,
            limit => undef );
    };

    return {
        -template     => 'report.html',
        title         => "Issue report",
        table_data    => $data,
        stat          => $stat,
        order_options => $model->report_order_options,
        status_pairs  => $model->get_status_pairs,
        form          => $form,
    };
});

MVC::Neaf->route( add_watch => sub {
    my $req = shift;

    die 403 if (!$req->session->{user_id});

    my $issue = $req->param( issue_id => '\d+' );
    die 422 if (!$issue);

    my $del = $req->param( delete => '.+' );

    if ($del) {
        $model->del_watch( user_id => $req->session->{user_id}, issue_id => $issue );
    } else {
        $model->add_watch( user_id => $req->session->{user_id}, issue_id => $issue );
    };

    $req->redirect( "/issue/$issue" );
}); # TODO method => 'POST'

my $val_watch = MVC::Neaf::X::Form->new({
    min_created => '\d\d\d\d-\d\d-\d\d',
    max_created => '\d\d\d\d-\d\d-\d\d',
    # pagination
    limit       => '\d+',
    start       => '\d+',
    next         => '.+',
    prev         => '.+',
    start_report => '.+',
});
MVC::Neaf->route( watch => sub {
    my $req = shift;

    die 403 if (!$req->session->{user_id});

    my $form = $req->form( $val_watch );

    warn Dumper($req->dump);

    # TODO pagination copy-paste from report
    $form->data->{limit} ||= 0;
    $form->data->{start} ||= 0;
    if (delete $form->data->{next}) {
        $form->data->{start}+=$form->data->{limit};
        $form->raw->{start}+=$form->data->{limit};
    };
    if (delete $form->data->{prev}) {
        $form->data->{start}-=$form->data->{limit};
        $form->raw->{start}-=$form->data->{limit};
    };
    $form->data->{start} = 0
        if $form->data->{start} < 0 or delete $form->data->{start_report};

    my $result = [];
    my $stat;
    if ($form->is_valid) {
        $result = $model->watch_activity(
            order_by => "created", order_dir => 1,
            %{ $form->data },
            user_id => $req->session->{user_id}
        );
        $stat   = $model->watch_activity( %{ $form->data }, user_id => $req->session->{user_id}, count_only => 1 );
    };

    return {
        -template => 'watch.html',
        title => 'Activity stream',
        form => $form,
        table_data => $result,
        stat => $stat,
    };
});

MVC::Neaf->route( help => sub {
    my $req = shift;

    my ($topic) = $req->path_info =~ /(\w+)/;

    if (!$topic) {
        # TODO show listing
        die 404;
    };

    my $file = "$Bin/../help/$topic.md";
    my $fd;
    if (!open $fd, "<", $file) {
        # TODO tell 404 from actual error
        die 404;
    };

    my $title = <$fd>;
    local $/;
    my $body = <$fd>;

    return {
        -template => "help.html",
        title => "$title - Help",
        body => $body,
    };
});

MVC::Neaf->route( "/" => sub {
    my $req = shift;

    # this is main page ONLY
    die 404 if $req->path_info gt '/';

    return {
        -template => "main.html",
        title => "Potracheno - wasted time tracker",
    };
} );

MVC::Neaf->error_template( 403 => { -template => '403.html', title => "403 Forbidden" } );
MVC::Neaf->error_template( 404 => { -template => '404.html', title => "404 Not Found" } );

# TODO move to model OR view
sub DATE {
    my $time = shift;
    return strftime("%Y-%m-%d %H:%M:%S", localtime($time));
};

MVC::Neaf->run();
