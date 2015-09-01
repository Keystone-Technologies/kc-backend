package Keystone::Connect::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/url_escape/;

sub kcb_js {
    my $self = shift;

    $self->stash(user => undef);
    $self->render(template => 'kcb', format => 'js');
}

1;
