# vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4:
package Keystone::Connect;
use Mojo::Base 'Mojolicious';
use Keystone::Connect::Helpers qw//;

sub startup {
    my $self = shift;
    my $cfg  = $self->plugin(Config => { file => 'keystone-connect.conf' });

    $self->secrets($cfg->{secrets});

    for(qw/Timing Logging Pg/) {
        $self->plugin(sprintf('Keystone::Plugin::%s', $_) => $cfg->{plugins}->{lc($_)} || {});
    }

    Keystone::Connect::Helpers->install($self);

    # make sure to put login routes on the actual root, not on any of the version roots.
    my $root = $self->routes;
        $root->route('/kcb')->to('main#kcb_js');

    my $auth = $root->under('/auth');
        $auth->route('/facebook')->to('auth#facebook')->name('auth_facebook');
        $auth->route('/facebook_return')->to('auth#facebook_return')->name('auth_facebook_return');
}

1;
