package Keystone::Connect::Helpers;
use strict;
use warnings;
use Mojo::JSON qw/encode_json decode_json/;
use Mojo::Util qw/dumper/;

sub install {
    my $dummy = shift;
    my $app   = shift;

    $app->helper(get_user_for_js => sub {
        my $self = shift;
        return (defined($self->user)) ? encode_json($self->user) : 'null';
    });
    $app->helper(get_backend_url => sub { return shift->req->url->base });
    $app->helper(user => sub { return shift->stash('current_user') });
    $app->helper(tenant => sub { return shift->stash('current_tenant') });
    $app->helper(is_user_authenticated => sub { return (defined(shift->user)) ? 1 : 0 });
}

1;
