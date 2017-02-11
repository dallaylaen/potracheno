#!/usr/bin/env perl

use strict;
use warnings;
our $VERSION = 0.1007;

use URI::Escape;
use Data::Dumper;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);
use Encode;
use LWP::UserAgent;

use File::Basename qw(dirname);
use lib dirname(__FILE__)."/../lib", dirname(__FILE__)."/../local/lib";
use MVC::Neaf 0.14;
use MVC::Neaf qw(neaf_err);
use MVC::Neaf::X::Form;
use MVC::Neaf::X::Form::Data;
use App::Its::Potracheno::Model;

$SIG{__WARN__} = sub {
    print STDERR join " ", DATE(time), "[$$]", $_[0];
};

my $Bin = dirname(__FILE__); # FindBin doesn't seem to work well under plackup

my $conf = {
    db => {
        handle => "dbi:SQLite:dbname=$Bin/../local/potracheno.sqlite",
    },
};

# Will consume config later
my $model = App::Its::Potracheno::Model->new(
    config => $conf, # fallback value
    config_file => "$Bin/../local/potracheno.cfg",
    ROOT   => "$Bin/..",
);

MVC::Neaf->load_view( TT => TT =>
    INCLUDE_PATH => "$Bin/../tpl",
    PRE_PROCESS  => "inc/head.html",
    POST_PROCESS => "inc/foot.html",
    EVAL_PERL => 1,
    FILTERS => {
        int     => sub { return int $_[0] },
        time    => sub { return $model->time2human($_[0]) },
        render  => sub { warn "undef render" unless defined $_[0]; return $model->render_text($_[0]) },
        date    => \&DATE,
    },
)->render({ -template => \"\n\ntest\n\n" });

MVC::Neaf->set_path_defaults( '/',
    , { version => "$VERSION/".App::Its::Potracheno::Model->VERSION } );

MVC::Neaf->set_session_handler( engine => $model, view_as => 'session' );

MVC::Neaf->static( 'favicon.ico' => "$Bin/../html/i/icon.png" );
MVC::Neaf->static( fonts         => "$Bin/../html/fonts" );
MVC::Neaf->static( css           => "$Bin/../html/css" );
MVC::Neaf->static( i             => "$Bin/../html/i" );
MVC::Neaf->static( js            => "$Bin/../html/js" );

###################################
#  Routes

MVC::Neaf->route( login => sub {
    my $req = shift;

    my $name = $req->param( name => '\w+' );
    my $pass = $req->param( pass => '.+' );
    my $return_to = $req->param( return_to => '/.*');

    # If return_to not given, make up from referer
    if (!$return_to and my $from = $req->referer) {
        $return_to = $from =~ m#https?://[^/]+(/.*)# ? $1 : "/";
    };

    my $data;
    my $wrong;
    if ($req->method eq 'POST' and $name and $pass) {
        $data = $model->login( $name, $pass );
        $wrong = "Login failed!";
    };
    if ($data) {
        warn "USER LOGGED IN: $name";
        $req->save_session( $data );
        $req->redirect( $return_to );
    };

    return {
        -template => 'login.html',
        title     => 'Log in',
        wrong     => $wrong,
        name      => $name,
        return_to => $return_to,
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
my $re_tag = qr(\w+(?:-\w+)*);
my $val_post = MVC::Neaf::X::Form->new({
    summary   => [ required => qr/\S.+\S/ ],
    body      => [ required => qr/.*\S.+/s ],
    sign      => '.+',
    create    => '.+',
    issue_id  => '\d+',
    tags_str  => qr/(?:\s*$re_tag\s*)*/,
});
MVC::Neaf->route( post => sub {
    my $req = shift;

    my $user = $req->session;
    my $form = $req->form( $val_post );
    $user->{user_id} or $form->error( user => "Please log in to post issues" );

    $form->data->{sign} ||= '';

    # TODO form->hmac( "salt" )
    my $sign = $form->is_valid
        ? md5_base64( encode_utf8( join "\n\n", $user->{user_id}, $form->data->{summary}
            , $form->data->{body}, $form->data->{tags_str} ) )
        : '';

    if ($sign ne $form->data->{sign} || !$form->data->{create}) {
        $form->error( preview_mode => 1 );
        $form->raw->{sign} = $sign;
    };
    $form->data->{tags_alpha} =
        [ map { lc } $form->data->{tags_str} =~ /(\S+)/g ]
            if defined $form->data->{tags_str};

    if ( $req->method eq 'POST' and $form->is_valid ) {
        my $id = $model->save_issue( user => $user, issue => $form->data);
        $model->add_watch(user_id => $user->{user_id}, issue_id => $id);

        $model->tag_issue(issue_id => $id, tags => $form->data->{tags_alpha} );
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

# Add autoupdate detection to ticket display
# TODO Remove this hack from here when Neaf gets periodic jobs
my $UPDATE_INTERVAL = $model->get_config("update", "interval");
my $UPDATE_COOLDOWN = $model->get_config("update", "cooldown")
    || $UPDATE_INTERVAL / 10;
my $UPDATE_DUE = time + $UPDATE_COOLDOWN;
my $UPDATE_AVAIL = {};
my $UPDATE_LINK = $model->get_config("update", "link")
    || "https://raw.githubusercontent.com/dallaylaen/potracheno/master/Changes";
MVC::Neaf->set_path_defaults( '/', { auto_update => $UPDATE_AVAIL } );

sub auto_update {
    warn "Checking for updates at $UPDATE_LINK";

    # avoid spamming github too often
    $UPDATE_DUE = time + $UPDATE_COOLDOWN;

    my $ua = LWP::UserAgent->new;
    my $resp = $ua->get($UPDATE_LINK);
    return unless $resp->is_success;
    return unless $resp->decoded_content =~ m#^(\d+\.\d+)#m;

    my $ver = $1;
    warn "Got version $ver, ours is $VERSION";

    if ($ver > $VERSION) {
        # Got it - no more checking needed
        # TODO or should we save it to a file?
        $UPDATE_INTERVAL = 0;
        $UPDATE_AVAIL->{version} = $ver+0; # conversion avoids utf issues
    } else {
        $UPDATE_DUE = time + $UPDATE_INTERVAL;
    };
};

MVC::Neaf->route( issue => sub {
    my $req = shift;

    my $id = $req->path_info || $req->param ( id => '\d+' );
    my $show_all = $req->param(all => 1);
    die 422 unless $id;

    my $data = $model->get_issue( id => $id );
    die 404 unless $data->{issue_id};

    my $comments = $model->get_comments(
        issue_id => $id, sort => '+created', text_only => !$show_all);

    my $watch = $model->get_watch(
        user_id => $req->session->{user_id}, issue_id => $id );

    if ($UPDATE_INTERVAL && time >= $UPDATE_DUE) {
        $req->postpone(\&auto_update);
    };

    return {
        -template => "issue.html",
        title     => "#$data->{issue_id} - $data->{summary}",
        issue     => $model->render_issue($data),
        comments  => $comments,
        statuses  => $model->get_status_pairs,
        watch     => $watch,
    };
}, path_info_regex => '\d+' );

my $search_limit = $model->get_config( search => "limit" ) || 10;

MVC::Neaf->route( search => sub {
    my $req = shift;

    my $q      = $req->param( q => '.*' );
    my $page   = $req->param( page => '\d+' );
    my $start  = $req->param( start => '\d+' );
    my $seen   = $req->param( seen  => '[\d.]+' );
    my @term = $q =~ /([\w*?]+)/g;

    my ($result, $next_start) = $model->search(
        terms => \@term, limit => $search_limit, start => $start);

    $seen .= ".$_->{issue_id}" for @$result;

    return {
        -template  => 'search.html',
        title      => "Search results for @term",
        results    => $result,
        q          => $q,
        terms      => \@term,
        page       => $page || 1,
        next_start => $next_start,
        limit      => 1,
        seen       => $seen,
        last       => (@$result < $search_limit),
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
        if ( $note or defined $status_id) {
            $model->add_watch(user_id => $user->{user_id}, issue_id => $issue_id);
        };
    };

    $req->redirect( "/issue/$issue_id" );
}, method => "POST" );

MVC::Neaf->route( user => sub {
    my $req = shift;

    my $id = $req->param( user_id => '\d+', $req->path_info );
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
}, path_info_regex => '\d+');

our %pagination = (
    order_by     => '\w+',
    order_dir    => '.*',
    limit        => '\d+',
    start        => '\d+',
    next         => '.+',
    prev         => '.+',
    start_scratch => '.+',
);

my $val_browse = MVC::Neaf::X::Form->new({
    min_a_created    => '\d\d\d\d-\d\d-\d\d',
    max_a_created    => '\d\d\d\d-\d\d-\d\d',
    has_solution => '\d',
    status       => '\d+',
    status_not   => '.+',
    ready        => '.+',
    pi_factor    => '\d+\.?\d*',
    min_time_spent => '.+',
    max_time_spent => '.+',
    min_best_estimate => '.+',
    max_best_estimate => '.+',
    %pagination,
});
MVC::Neaf->route( browse => sub {
    my $req = shift;

    my $form = $req->form( $val_browse );
    return _do_browse( $form );
});

MVC::Neaf->route( browse => tag => sub {
    my $req = shift;

    my $form = $req->form( $val_browse );
    my $tag = $req->path_info;

    $form->data( tag => $tag );

    return _do_browse( $form );
}, path_info_regex => $re_tag );

my $val_stats = MVC::Neaf::X::Form->new({
    min_a_created    => '\d\d\d\d-\d\d-\d\d',
    max_a_created    => '\d\d\d\d-\d\d-\d\d',
    tag_like         => '[-\w]+',
    %pagination,
});
MVC::Neaf->route( stats => sub {
    my $req = shift;

    my $form = $req->form( $val_stats );
    _form_paginate( $form );

    my ($tag_info, $tag_count, $total);

    if ($form->is_valid) {
        my $opt = $form->data;
        $tag_info   = $model->get_tag_stats( %$opt ); # TODO form
        $tag_count  = $model->get_tag_stats( %$opt, count_only => 1 );
        $total      = $model->get_stats_total( %$opt );
    };

    return {
        -template  => 'stats.html',
        title      => 'Statistics',
        table_data => $tag_info,
        stat       => $tag_count,
        total      => $total,
        form       => $form,
        order_options => [[name => "Tag name"], [time_spent => "Time spent"]],
    };
});

sub _form_paginate {
    my ($form) = @_;

    # TODO Use form->defaults when they appear
    if (!defined $form->data->{limit}) {
        $form->data->{limit} = 20;
        $form->raw->{limit} = 20;
    };
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
        if $form->data->{start} < 0 or delete $form->data->{start_scratch};

    return $form;
};

sub _do_browse {
    my ($form) = @_;

    _form_paginate( $form );
    $form->data->{status_not} = !!$form->data->{status_not};

    my $data = [];
    my $stat;
    if ($form->is_valid) {
        $data = $model->browse( %{ $form->data } );
        $stat = $model->browse( %{ $form->data }, count_only => 1 );
    };

    return {
        -template     => 'browse.html',
        title         => "Browse issues",
        table_data    => $data,
        stat          => $stat,
        order_options => $model->browse_order_options,
        status_pairs  => $model->get_status_pairs,
        form          => $form,
    };
};

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

my $val_feed = MVC::Neaf::X::Form->new({
    min_created  => '\d\d\d\d-\d\d-\d\d',
    max_created  => '\d\d\d\d-\d\d-\d\d',
    all          => '.+',
    %pagination,
});
MVC::Neaf->route( feed => sub {
    my $req = shift;

    die 403 if (!$req->session->{user_id});

    my $form = $req->form( $val_feed );

    _form_paginate( $form );

    my $result = [];
    my $stat;
    if ($form->is_valid) {
        $result = $model->watch_feed(
            order_by => "created", order_dir => 1,
            %{ $form->data },
            user_id => $req->session->{user_id},
        );
        $stat   = $model->watch_feed(
            %{ $form->data },
            user_id => $req->session->{user_id},
            count_only => 1,
        );
    };

    return {
        -template => 'feed.html',
        title => 'Activity stream',
        form => $form,
        table_data => $result,
        stat => $stat,
    };
});

MVC::Neaf->route( help => sub {
    my $req = shift;

    my $topic = $req->path_info;

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
}, path_info_regex => '\w+');

# TODO configurable?..
undef $!;
my $greeting_file = "$Bin/../local/welcome.md";
my $greeting = do {
    local $/;
    my $fd;
    open $fd, "<", $greeting_file
        and <$fd>;
};
die "Failed to load greeting from $greeting_file: $!"
    unless defined $greeting or $!{ENOENT};

MVC::Neaf->route( "/" => sub {
    my $req = shift;

    my $user_id = $req->session->{user_id};
    my $feed = $user_id &&
        $model->watch_feed(
            order_by  => "created", order_dir => 1, limit => 10,
            user_id   => $user_id,
        );

    return {
        feed       => $feed,
        greeting   => $greeting,
        -template  => "main.html",
        title      => "Welcome to the wasted time tracker",
    };
}, path_info_regex => '' );

MVC::Neaf->set_error_handler( 403 => {
    -template => '403.html',
     title => "403 Forbidden",
     version => "$VERSION/".App::Its::Potracheno::Model->VERSION,
} );
MVC::Neaf->set_error_handler( 404 => {
    -template => '404.html',
     title => "404 Not Found",
     version => "$VERSION/".App::Its::Potracheno::Model->VERSION,
} );

################################
# Some extra hacks

# TODO move to model OR view
sub DATE {
    my $time = shift;
    return strftime("%Y-%m-%d %H:%M:%S", localtime($time));
};

# TODO UGLY HACK - remove after Form is updated.
# Monkey patch form into showing itself as url
# pointing to the same form again, with some additions
if (!MVC::Neaf::X::Form::Data->can("as_url")) {
    *MVC::Neaf::X::Form::Data::as_url = # avoid warn
    *MVC::Neaf::X::Form::Data::as_url = sub {
        my ($self, %override) = @_;

        my %data = ( %{ $self->{raw} }, %override );
        return join "&"
            , map { uri_escape($_)."=".uri_escape_utf8($data{$_}) }
            grep { defined $data{$_} && length $data{$_} }
            keys %data;
    };
};


MVC::Neaf->run();
