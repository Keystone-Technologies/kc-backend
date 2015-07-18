# vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4:
package Keystone::Connect;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;
    my $cfg  = $self->plugin(Config => { file => 'keystone-connect.conf' });

    $self->secrets($cfg->{secrets});

    for(qw/Timing Logging Pg/) {
        $self->plugin(sprintf('Keystone::Plugin::%s', $_) => $cfg->{plugins}->{lc($_)} || {});
    }

    # make sure to put login routes on the actual root, not on any of the version roots.
    my $root = $self->routes;
    my $auth = $root->under('/auth');
        $auth->route('/facebook')->to('auth#facebook')->name('auth_facebook');
}

1;
