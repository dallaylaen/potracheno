package App::Its::Potracheno::Update;

use strict;
use warnings;
our $VERSION = 0.1101;

=head1 NAME

App::Its::Potracheno::Update - Auto-update handler for Potracheno ITS.

=head1 SYNOPSIS

    use App::Its::Potracheno::Update;
    my $upd = App::Its::Potracheno::Update->new(
        interval => 3600,
        update_link => 'file:///dev/null',
    );

    $upd->is_due and $version_hash = $upd->run_update;

This module uses LWP::UserAgent to fetch web-page where next Potracheno release
is supposed to be.

This module is hacky and low-quality, but it works. Deal with it.
Better version TBD.

=head1 METHODS

=cut

use LWP::UserAgent;

=head2 new( %options )

%options may include:

=over

=item * interval - interval in seconds

=item * cooldown - interval in case fetching update failed (e.g. network down).

=item * update_link - where to fetch update from
(default is Potracheno's github page).

=back

The page by the link is supposed to contain either C<^\d+.\d+> (changelog)
or C<our $VERSION = \d+.\d+> (a module).

=cut

sub new {
    my ($class, %opt) = @_;

    $opt{version}      ||= $VERSION;
    $opt{interval}     ||= 0;
    $opt{cooldown}     ||= $opt{interval} / 10;
    $opt{update_avail} ||= {};
    $opt{update_due}     = time + $opt{cooldown}
        if $opt{interval};
    $opt{update_link}  ||= "https://raw.githubusercontent.com/dallaylaen/potracheno/master/Changes";

    return bless \%opt, $class;
};

=head2 permanent_ref()

Get a hash reference that is B<guaranteed> to stay available and be updated
if update() succeeds.

This is a suboptimal solution (because of a global var)
but this is how potracheno checks updates right now.

=cut

sub permanent_ref {
    my $self;
    return $self->{update_avail};
};

=head2 is_due()

Tell whether it's time for the next update.

=cut

sub is_due {
    my $self = shift;
    return $self->{interval} && $self->{update_due} > time;
};

=head2 run_update()

Fetch data from remote via LWP, look for version information.

Returns nothing if update fails, { version => ... } if version was fetched.

=cut

sub run_update {
    my $self = shift;

    return unless $self->{interval};

    warn "INFO Checking for updates at $self->{update_link}\n";

    # avoid spamming github too often
    $self->{update_due} = time + $self->{cooldown};

    my $ver = eval {
        local $SIG{ALRM} = sub { die "Timeout 10s" };
        alarm 10;
        my $ua = LWP::UserAgent->new;
        my $resp = $ua->get($self->{update_link});
        die "Bad response: ".$resp->status_line unless $resp->is_success;
        die "No version in response"
            unless $resp->decoded_content =~ m#^(?:our  *\$VERSION *= *)?(\d+\.\d+)#m;
        $1;
    };

    if (!$ver) {
        warn "Failed to fetch update: $@";
        return;
    };

    warn "INFO Update: got version $ver, ours is $self->{version}";

    if ($ver > $self->{version}) {
        # Got it - no more checking needed
        # TODO or should we save it to a file?
        $self->{interval} = 0;
        $self->{update_avail}->{version} = $ver+0; # conversion avoids utf issues
        return $self->{update_avail};
    } else {
        $self->{update_due} = time + $self->{interval};
    };

    return;
};

1;
