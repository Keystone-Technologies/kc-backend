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
    my $auth = $self->routes->under('/auth');
        $auth->route('/signout')->to('auth#signout')->name('auth_signout');
        $auth->route('/facebook')->to('auth#facebook')->name('auth_facebook');
        $auth->route('/facebook_return')->to('auth#facebook_return')->name('auth_facebook_return');

    my $root = $self->routes->under('/')->to('auth#validate_kc_token')->name('validate_kc_token_bridge');
        $root->route('/kcb')->to('main#kcb_js')->name('kcb_js');

    my $v1 = $root->under('/v1.0')->name('api_v1');
        my $v1_me = $v1->under('/me')->name('api_v1_me');
            $v1_me->route->via(qw/GET/)->to('api-v1#me_get_grid')->name('api_v1_me_get_grid');
            $v1_me->route->via(qw/POST/)->to('api-v1#me_set_grid')->name('api_v1_me_set_grid');
}

1;
