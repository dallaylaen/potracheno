package App::Its::Potracheno::Config;

use strict;
use warnings;
our $VERSION = 0.10;

# TODO replace with stock module!!!!!

=head1 DESCRIPTION

Potracheno uses an ini file with optional JSON values.
Format is as follows:

    # This is a comment

    [ section ]
    # whatever comes below will appear under {section}{...}
    # section name may be bareword (see below)

    param = bareword1
    # param name MUST start with a [A-Za-z_] and MAY contain [A-Za-z_\-0-9\.]
    # As for config values (and secrion names),
    # [-A-Za-z_0-9.:/?&=+%@] allowed - i.e. numbers, hyperlinks & email ok

    param = "quoted text with spaces"
    # NO GO - duplicate param

    param2 = "quoted text with spaces";
    # optional semicolon at the end

    param3 = { "json":"here", "for":"complex", "values":"!" }
    # JSON

    param4 = "very\
          long \
          # inline comment
          value"
    # Use backslashes at end of line for continuation.
    # All whitespace after \, on both same and next line, is ignored
    # So you get "verylong value" with EXACTLY one space
    # Comments are still ignored (useful for commenting out parts of a value)
    # Put literal hashes and whitespace before \ if you need them

=cut

use JSON::XS;
use Errno qw(ENOENT);

use parent qw(MVC::Neaf::X); # get my_croak

=head2 load_config( $filename, %defaults )

One and only public static method for now.
Loads config and returns a hash.

As a special case, if file is missing, nothing is returned.
All other errors will die.

=cut

my $key = qr{[A-Za-z_0-9\.\-]+};
my $bareword = qr{[A-Za-z_0-9\.\-:/&=\?\@]+};
my %replace = (qw( ' ' " " \ \ ), n =>"\n");
my $js = JSON::XS->new->relaxed;

sub load_config {
    my ($self, $file, %opt) = @_;

    my $fd;
    if (!open ($fd, "<", $file)) {
        return if $!{ENOENT};
        $self->my_croak("Failed to load config $file: $!");
    };

    my %conf;
    $conf{global} = \%opt if %opt;
    my @cont;
    my $line;
    my $section = "global";
    while (<$fd>) {
        $line++;
        # skip comments and whitespace
        /^\s*#/ and next;
        /\S/ or next;

        # continuation first
        s/^\s+//;
        if (/^(.*)\\\s*$/s) {
            push @cont, $1;
            next;
        };

        # concatinate the value
        $_ = join "", @cont, $_;
        @cont = ();

        # Now parse!
        # TODO accumulate ALL parse errors

        # section must be bareword. Duplicate section ok, duplicate values not.
        if (/^\[/) {
            /^\[\s*($bareword)\s*\]\s*$/
                or $self->my_croak( "Bad section definition at $file line $line" );
            $section = $1;
            next;
        };

        # single value. Clean trailing \w; and figure out the name
        s/\s*;?\s*$//s;
        s/^\s*($key)\s*=\s*//s
            or $self->my_croak( "Bad file format in $file line $line ([$section])" );
        my $param = $1;
        exists $conf{$section}{$param}
            and $self->my_croak( "Duplicate value [$section].$param in $file line $line" );

        # Name is ok, process value
        # NOTE whitespace is killed - can go ^$!
        # bareword
        if (/^($bareword)$/) {
            $conf{$section}{$param} = $1;
            next;
        };

        # quoted text
        if (/^(["'])((?:[^"']+|\\["'\\])*)\1$/) {
            my $value = $2;
            $value =~ s/\\(['"\n\\])/$replace{$1}/gs;

            $value =~ s[\$\((?:($bareword)\#)?($key)\)][
                my $sec = defined $1 ? $1 : "global";
                exists $conf{$sec}{$2}
                    or $self->my_croak("Unknown value \$($sec#$2) substituted at $file line $line");
                $conf{$sec}{$2};
            ]xge;

            $conf{$section}{$param} = $value;
            next;
        };

        # json
        if (/^([\{\[].*[\}\]])$/) {
            eval { $conf{$section}{$param} = $js->decode($1); 1 }
                or $self->my_croak( "Bad json at $file line $line: $@" );
            next;
        };

        # if got here, something went wrong
        $self->my_croak("Unknown value format at $file line $line");
    };

    return \%conf;
};

1;
