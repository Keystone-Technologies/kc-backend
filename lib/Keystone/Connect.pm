# vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4:
package Keystone::Connect;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;
    $self->routes->get('/' => sub { shift->render(text => scalar localtime) });
}

1;
