package Keystone::Connect::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/url_escape/;

sub generate_nonce {
    my $self = shift;
    my @a    = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
    my $cb   = shift;

    # could be done with Data::UUID but then again, that's just another dependency that
    # we don't really want 
    my $nonce = '';
    my $now   = time() + 0;

    $nonce .= $a[$_] for(split(//, $now));

    while(length($nonce) < 48) {
        $nonce .= $a[int(rand(scalar(@a)))];
    }

    $self->db->query('SELECT id FROM auth_nonce WHERE nonce = ?', $nonce => sub {
        my ($db, $err, $results) = (@_);

        if($results->rows == 0) {
            $self->db->query('INSERT INTO auth_nonce (nonce, used) VALUES (?, 0)', $nonce => sub {
                return $cb->($self, $nonce);
            });
        } else {
            # it exists already, which is a bit of a pain, so let's do this again. 
            # yes, there is a chance that this can recurse in a hideous fashion...
            return $self->generate_nonce($cb);
        }
    });
}


sub facebook { 
    my $self = shift;
    my $root = $self->req->param('r');

    $self->render_later;

    # if no t parameter is supplied, we need to holler
    if(!defined($self->req->param('t'))) {
        $self->redirect_to(sprintf('%s?status=error&error=KC_NO_TENANT_SUPPLIED', $root));
    } else {
        $self->db->query('SELECT t.* FROM tenant t, tenant_map tm WHERE tm.hostname = ? AND tm.tenant = t.id', $self->req->param('t') => sub {
            my ($db, $err, $res) = (@_);

            if(defined($err)) {
                $self->redirect_to(sprintf('%s?status=error&error=KC_INVALID_TENANT', $root));
            } else {
                $self->session(auth => { root => $root, tenant => $res->hash->{id} });

                # make sure that actually does what it's supposed to do

                $self->generate_nonce(sub {
                    my ($c, $nonce) = (@_);

                    my $return_url = sprintf('%s/auth/facebook_return/', $c->req->url->base);

                    $c->debug('Auth: facebook: return url set to ', $return_url, ' using nonce ', $nonce);

                    $c->redirect_to(
                        sprintf('https://www.facebook.com/dialog/oauth?client_id=%s&redirect_uri=%s&state=%s&response_type=token&scope=email',
                            $c->config('login')->{facebook}->{client_id},
                            $return_url,
                            $nonce,
                        )
                    );
                });
            }
        });
    }
}

sub redirect_root {
    my $self = shift;
    my %args = (@_);
    
    if($args{status} eq 'error') {
        $self->redirect_to(sprintf('%s?status=error&error=%s', $self->session('auth')->{root}, $args{error}));
    } else {
        $self->redirect_to(sprintf('%s?status=ok&token=%s', $self->session('auth')->{root}, $args{token}));
    }
}

sub facebook_return {
    my $self = shift;

    $self->render_later;

    if(defined($self->req->param('error'))) {
        $self->stash(is_error => 1, error => $self->req->param('error'));
        $self->redirect_root(status => 'error', error => 'FB_AUTH_ERROR');
    } elsif(my $nonce = $self->req->param('#state')) {
        $self->db->query('SELECT id FROM auth_nonce WHERE nonce = ?', $nonce => sub {
            my ($db, $err, $results) = (@_);

            if(my $nonce = $results->hash) {
                if($nonce->{used} > 0) {
                    $self->redirect_root(status => 'error', error => 'KC_NONCE_USED_ALREADY');
                } elsif(my $token = $self->req->param('access_token')) {
                    $self->ua->get('https://graph.facebook.com/debug_token' => form => {
                        input_token     => $token,
                        access_token    => $self->config('login')->{facebook}->{client_id},
                    } => sub {
                        my ($ua, $tx) = (@_);

                        if(my $res = $tx->success) {
                            if($res->json->{data}->{app_id} eq $self->config('login')->{facebook}->{client_id}) {
                                my $user_id = $res->json->{data}->{user_id};

                                # make a call to the graph API to get the user profile
                                $self->ua->get(sprintf('https://graph.facebook.com/v2.4/%s', $user_id) => form => {
                                    access_token => $token,
                                } => sub {
                                    my ($ua, $tx) = (@_);

                                    if(my $res = $tx->success) {
                                        # set up the user record in the database if we have one, if we don't then create it
                                        # associate a token with the user record as well, 

                                    } else {
                                        $self->redirect_root(status => 'error', error => 'FB_COULD_NOT_GET_EMAIL');
                                    }
                                });
                            } else {
                                $self->redirect_root(status => 'error', 'error' => 'FB_INVALID_APP');
                            }
                        }
                    });
                } else {
                    $self->redirect_root(status => 'error', error => 'FB_NO_TOKEN_RETURNED');
                }
            } else {
                $self->redirect_root(status => 'error', error => 'KC_NONCE_INVALID');
            }
        });
    } else {
        $self->redirect_root(status => 'error', error => 'KC_NONCE_EMPTY');
    }
}

1;
