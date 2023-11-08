package App::Its::Wasted::Routes;

use strict;
use warnings;
our $VERSION = 0.13;

=head1 NAME

App::Its::Wasted::Routes - a technical debt assessment tool.

=head1 DESCRIPTION

See L<App::Its::Wasted>.

Dragons be here.
Because L<MVC::Neaf> is not really ready to handle application of this size,
we do it manually by separating route definitions into a package.

This is essentially a PSGI script.

=cut

use Carp;
use URI::Escape;
use Data::Dumper;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);
use Encode;
use File::Basename qw(dirname);
use File::ShareDir qw(module_dir);

use MVC::Neaf qw(:sugar neaf_err);
use MVC::Neaf::X::Form;
use MVC::Neaf::X::Form::Data;
use App::Its::Wasted qw(silo);

# some basic regexps
my $re_w    = qr/[A-Za-z_0-9]+/;
my $re_id   = qr/[A-Za-z]$re_w/;
my $re_user = qr/$re_id(?:[-.]$re_w)*/;

# basically a JS wrapper
sub run {
    # Load model
    my $auto_update = silo->auto_update;
    my $model = silo->model;

    # set global vars TODO make better
    my $help = silo->dir( "help" );
    my $html = silo->dir( "html" );
    my $tpl  = silo->dir( "tpl"  );

    # Load view
    neaf( view => TT => TT =>
        INCLUDE_PATH => $tpl,
        PRE_PROCESS  => "inc/head.html",
        POST_PROCESS => "inc/foot.html",
        EVAL_PERL => 1,
        FILTERS => {
            int     => sub { return int $_[0] },
            time    => sub { return $model->time2human($_[0]) },
            render  => sub { warn "undef render" unless defined $_[0]; return $model->render_text($_[0]) },
            date    => \&_date,
        },
    ); #->render({ -template => \"\n\ntest\n\n" });
    neaf default => { -view => 'TT', foo => 42 }, path => '/';

    # Load static
    neaf static => 'favicon.ico' => "$html/i/icon.png";
    neaf static => fonts         => "$html/fonts";
    neaf static => css           => "$html/css";
    neaf static => i             => "$html/i";
    neaf static => js            => "$html/js";

    ###################################
    #  Routes
    #  TODO Move all routes inside run()

    # TODO use forms
    get+post '/auth/login' => sub {
        my $req = shift;

        my $name = $req->param( name => $re_user );
        my $pass = $req->param( pass => '.+' );
        my $return_to = $req->param( return_to => '/.*');

        # If return_to not given, make up from referer
        if (!$return_to and my $from = $req->referer) {
            $return_to = $from =~ m#https?://[^/]+(/.*)# ? $1 : "/";
            $return_to = '/' if $return_to =~ m#/auth#; # avoid redirect to login, logout etc
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
    };

    get+post '/auth/logout' => sub {
        my $req = shift;

        $req->delete_session;
        $req->redirect( '/' );
    };

    get+post '/auth/register' => sub {
        my $req = shift;

        my $user = $req->param( user => $re_user );
        if ($req->method eq 'POST') {
            eval {
                $user or die "FORM: [User must be nonempty alphanumeric]";
                # TODO refactor to forms

                my $pass;
                $pass  = $req->param( pass  => '.+' );
                $pass or die "FORM: [Password empty]";
                $pass eq $req->param( pass2 => '.+' )
                    or die "FORM: [Passwords do not match]";

                my $email = $req->param( email => '\S+\@\S+\.\S+' );
                # TODO email mandatory if configured so

                my $new_banned = silo->config->{security}{members_moderated};

                my $id = $model->add_user(
                   name => $user, pass => $pass, banned => $new_banned, email => $email );
                $id   or die "FORM: [Username '$user' already taken]";

                $req->save_session( { user_id => $id } );
                if ($new_banned) {
                    $req->redirect("/user/$id");
                } else {
                    $req->redirect("/");
                };
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
    };

    get+post edit_user => sub {
        my $req = shift;

        $req->redirect("/auth/login") unless $req->session->{user_id};
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
            if (my $email = $req->param( email => '\S+\@\S+\.\S+' ) ) {
                $details->{email} = $email;
            };

            $model->save_user( $details );
            $req->redirect( "/user/$details->{user_id}" );
        };

        return {
            -template => 'register.html',
            title => "Edit user $details->{name}",
            details => $details,
        };
    };

    get+post "/auth/forgot" => sub {
        my $req = shift;

        if ($req->is_post and my $user = $req->param(user => $re_user)) {
            if (my $user_data = $model->load_user( name => $user )) {
                my $base_url  = $req->scheme."://".$req->hostname.":".$req->port."/auth/setpass";
                my $reset_key = $model->request_reset( user_id => $user_data->{user_id} );
                warn "INFO password reset issued for $user: $base_url/$reset_key\n";
            };
            my $forgot_ttl   = silo->config->{security}{reset_ttl} || 24*60*60;

            return {
                -template => 'forgot.html',
                title     => 'Password reset successful for '.$user,
                user      => $user,
                valid     => time + $forgot_ttl,
            };
        };

        return {
            -template => 'forgot_form.html',
            title     => 'Password reset request',
        }
    };

    get+post "/auth/setpass" => sub {
        my $req = shift;

        my $reset_key = $req->path_info;

        my $user_id = $model->confirm_reset( reset_key => $reset_key );
        warn "INFO reset key=$reset_key, user=$user_id\n";

        if (!$user_id) {
            # TODO expired message
            $req->redirect( "/auth/forgot" );
        };

        my $nomatch;
        if ($req->is_post) {
            my $pass  = $req->param(pass  => ".*");
            my $pass2 = $req->param(pass2 => ".*");
            defined $pass and defined $pass2 and $pass eq $pass2
                or $nomatch++;
            if (!$nomatch) {
                $model->save_user( { user_id => $user_id, pass => $pass} );
                $model->delete_reset( user_id => $user_id );
                # TODO return success message
                $req->redirect( "/" );
            };
        };

        return {
            -template => 'reset_form.html',
            title     => "Password reset",
            reset_key => $reset_key,
            nomatch   => $nomatch,
        };
    }, path_info_regex => qr/[A-Za-z_0-9~]+/;

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
    get+post '/update/post' => sub {
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
    };

    get+post "/update/edit_issue" => sub {
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
            post_to   => "/update/post",
        };
    };

    get+post issue => sub {
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

        return {
            -template => "issue.html",
            title     => "#$data->{issue_id} - $data->{summary}",
            issue     => $model->render_issue($data),
            comments  => $comments,
            statuses  => $model->get_status_pairs,
            watch     => $watch,
        };
    }, path_info_regex => '\d+';

    get+post search => sub {
        my $req = shift;

        my $q      = $req->param( q => '.*' );
        my $page   = $req->param( page => '\d+' );
        my $start  = $req->param( start => '\d+' );
        my $seen   = $req->param( seen  => '[\d.]+' );
        my @term = $q =~ /([\w*?]+)/g;

        my $search_limit = silo->config->{search}{limit} || 10;

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
    };

    # fetch usr
    # model. add time
    # return to view
    post '/update/add_time' => sub {
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
    };

    # UPDATE SECTION
    # Require user being logged in for ALL requests under /update
    neaf pre_logic => sub {
        my $req = shift;
        $req->session->{allow} or die 403;
    }, path => '/update';

    my $edit_time_form = MVC::Neaf::X::Form->new({
    #    issue_id     => qr/\d+/,
        seconds      => qr/.*[\d.].*/,
        note         => qr/.*\S.+/s,
        activity_id  => [ required => qr/\d+/ ],
    });
    post '/update/edit_time' => sub {
        my $req = shift;

        my $form = $req->form( $edit_time_form );
        if ($form->is_valid) {
            my $data = { %{ $form->data } }; # shallow copy
            $data->{seconds} = $model->human2time( $data->{seconds} );
            $data->{note} .= "\n\n*Edited "._date(time)."*";
            my $id = delete $data->{activity_id};

            $model->edit_record(
                table       => 'activity',
                condition   => { activity_id => $id, fix_estimate => undef },
                permission  => { user_id => $req->session->{user_id} },
                data        => $data,
            );

            my $item = $model->get_comments( activity_id => $id )->[0];

            $req->redirect(sprintf "/issue/%u#a%u"
                , $item->{issue_id}, $form->data->{activity_id});
        };

        return {
            -template  => 'edit_time.html',
            title      => 'Edit time entry',
            form       => $form,
        };
    };

    get '/update/edit_time' => sub {
        my $req = shift;

        my $id = $req->param( activity_id => '\d+' );
        die 404 unless $id;

        my $item = $model->get_comments( activity_id => $id )->[0];
        die 404 unless $item;

        return {
            -template  => 'edit_time.html',
            title      => 'Edit time entry',
            form       => { raw => $item, data => $item, error => {} },
        };
    };

    get+post user => sub {
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
    }, path_info_regex => '\d+';

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
    my $_do_browse = sub {
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

    get+post browse => sub {
        my $req = shift;

        my $form = $req->form( $val_browse );
        return $_do_browse->( $form );
    };

    get+post '/browse/tag' => sub {
        my $req = shift;

        my $form = $req->form( $val_browse );
        my $tag = $req->path_info;

        $form->data( tag => $tag );

        return $_do_browse->( $form );
    }, path_info_regex => $re_tag;

    my $val_stats = MVC::Neaf::X::Form->new({
        min_a_created    => '\d\d\d\d-\d\d-\d\d',
        max_a_created    => '\d\d\d\d-\d\d-\d\d',
        tag_like         => '[-\w]+',
        %pagination,
    });
    get+post stats => sub {
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
    };

    get+post add_watch => sub {
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
    }; # TODO method => 'POST'

    my $val_feed = MVC::Neaf::X::Form->new({
        min_created  => '\d\d\d\d-\d\d-\d\d',
        max_created  => '\d\d\d\d-\d\d-\d\d',
        all          => '.+',
        %pagination,
    });
    get+post feed => sub {
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
    };

    get+post help => sub {
        my $req = shift;

        my $topic = $req->path_info;
        $topic =~ s#\.md$##;
        my $file = "$help/$topic.md";

        my $body = _cached_slurp( $file );
        die 404 unless $body; # TODO tell this from actual mistyped url

        $body =~ s/^([^\n]+)\n\n+//
            or warn "Bad format in file $file, must be title\\n\\nmarkdown";
        my $title = $1 || $topic;

        return {
            -template => "help.html",
            title => "$title - Help",
            body => $body,
        };
    }
        , path_info_regex => '\w+(?:\.md)?'
        , description => 'Generated from help/*.md'
    ;

    neaf pre_logic => sub {
        my $req = shift;
        $req->session->{admin} or die 403
    }, path => '/admin';

    get '/admin/user' => sub {
        my $req = shift;

        my $search = $req->param( q => '.+' );

        my $list = defined $search ? $model->find_user ( like => $search ) : [];
        # TODO no pagination

        return {
            users => $list,
            q     => $search,
            title => 'User access administration',
        };
    }, -template => 'admin_user.html';

    my %ADMIN_TODO = (
        ban => sub { $_[0]->{banned} = 1 },
        unban => sub { $_[0]->{banned} = 0 },
        admin => sub { $_[0]->{admin} = 1 },
        unadmin => sub { $_[0]->{admin} = 0 },
    );
    my $ADMIN_TODO_RE = join "|", keys %ADMIN_TODO;
    $ADMIN_TODO_RE = qr/$ADMIN_TODO_RE/;

    post '/admin/user' => sub {
        my $req = shift;

        my $user = $req->param(user_id => '\d+');
        my $todo = $req->param(action => $ADMIN_TODO_RE);

        if ($user and $todo) {
            # TODO this should be UPDATE!1111
            my $data = $model->load_user( user_id => $user )
                or die 404;
            $ADMIN_TODO{$todo}->($data);
            $model->save_user($data);
        } else {
            # TODO report invalid action properly
            die 422;
        };

        # TODO this is a shame, patch Neaf to get rid
        my $q = $req->param(q => '.+');
        $req->redirect( '/admin/user'. (defined $q ? "?q=". uri_escape($q) : '' ) );
    };

    get+post "/" => sub {
        my $req = shift;

        my $greeting_file = $model->get_config("help", "greeting") || 'greeting.md';
        my $greeting = _cached_slurp( $greeting_file );

        my $title = "Welcome to the wasted time tracker";
        if ($greeting) {
            $greeting =~ s/^([^\n]+)\n\n+//s
                or warn "Bad greeting format, should be title\\n\\nmarkup in $greeting_file";
            $title = $1 || $title;
        };

        my $user_id = $req->session->{user_id};
        my $feed = $user_id &&
            $model->watch_feed(
                order_by  => "created", order_dir => 1, limit => 10,
                user_id   => $user_id,
            );

        return {
            -template  => "main.html",
            feed       => $feed,
            greeting   => $greeting,
            title      => $title,
        };
    }, path_info_regex => '';

    neaf 403 => {
        -view     => 'TT',
        -template => '403.html',
         title    => "403 Forbidden",
         version  => "$VERSION/".App::Its::Wasted::Model->VERSION,
    };
    neaf 404 => {
        -view     => 'TT',
        -template => '404.html',
         title    => "404 Not Found",
         version  => "$VERSION/".App::Its::Wasted::Model->VERSION,
    };

    ################################
    # Some extra hacks
    neaf session => $model, view_as => 'session', cookie => 'potracheno.sess';

    neaf default => {
        version => "$VERSION/".App::Its::Wasted::Model->VERSION,
        auto_update => $auto_update->permanent_ref,
    } => path => '/';
    if ($auto_update->is_due) {
        neaf pre_cleanup => sub { $auto_update->is_due and $auto_update->run_update }
            , path => '/issue';
    };

    # Some extra routes
    if ($model->get_config("security", "members_only")) {
        # only allow static and logging in
        neaf pre_logic => sub {
            my $req = shift;
            die 403 unless $req->session->{allow};
        }, exclude => [qw[auth css favicon.ico fonts i js help]];
    };

    return neaf->run;
}; # end of sub run

# Some auxiliary subs used by run()
# TODO this all should be Potracheno::Util or smth...

sub _my_dir {
    my ($conf, $name) = @_;

    my @list = map { "$_/$name" } qw(share ../share)
        , eval {
            local $SIG{__WARN__} = sub {};
            module_dir(__PACKAGE__);
        };
        # skip exception - will die anyway if not found

    return $conf->get( files => $name )
        || $conf->find_dir( @list )
        || croak("Failed to locate directory /$name anywhere under @list");
};

sub _date {
    my $time = shift;
    return strftime("%Y-%m-%d %H:%M:%S", localtime($time));
};

# TODO rewrite in understandable manner
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

# _cached_slurp(file)
# TODO use separate module
# return: content or undef if no such file
# dies on error!=ENOENT
my $slurp_ttl = 5;
my %slurp_cch;
sub _cached_slurp {
    my ($file) = @_;

    if (my $entry = $slurp_cch{$file}) {
        if ($entry->[1] > time) {
            return $entry->[0];
        } else {
            delete $slurp_cch{$file};
        };
    };

    my $content;
    if (open my $fd, "<", $file) {
        local $/;
        $content = <$fd>;
        defined $content or die "Failed to read from $file: $!";
    } elsif( not $!{ENOENT} ) {
        # File's there, but something's not right!
        die "Failed to open(r) $file: $!";
    };

    # cache 404s as well
    $slurp_cch{$file} = [ $content, time + $slurp_ttl ];
    return $content;
};

1;
