package Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.01;

sub new {
    my ($class, %opt) = @_;
    return bless \%opt, $class;
};

sub get_user {
    my ($self, %opt) = @_;

    my $name = $opt{name};
    return $self->{user_by_name}{$name} ||= do {
        my $data = {
            name => $name,
            id   => ++$self->{id_user},
        };
        $self->{user_by_id}{ $data->{id} } = $data;
        $data;
    };
};

sub add_article {
    my ($self, %opt) = @_;

    my $data = {
        id => ++$self->{id_article},
        summary => $opt{summary},
        body => $opt{body},
        author_id => $opt{user}{id},
        author   =>  $opt{user}{name},
    };

    $self->{article_by_id}{ $data->{id} } = $data;

    return $data->{id};
};

sub get_article {
    my ($self, %opt) = @_;

    my $data = $self->{article_by_id}{ $opt{id} };
};

1;
