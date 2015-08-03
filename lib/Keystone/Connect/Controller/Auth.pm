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
                        sprintf('https://www.facebook.com/dialog/oauth?client_id=%s&redirect_uri=%s&state=%s&response_type=code&scope=email',
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

sub facebook_exchange_code_for_token {
    my $self = shift;
    my $code = shift;
    my $cb   = shift;

    $self->ua->get('https://graph.facebook.com/v2.4/oauth/access_token' => form => {
        client_id       => $self->config('login')->{facebook}->{client_id},
        redirect_uri    => sprintf('%s/auth/facebook_return/', $c->req->url->base),
        client_secret   => $self->config('login')->{facebook}->{client_secret},
        code            => $code
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            if(defined($res->json->{error})) {
                return $cb->($self, $res->json->{error}, undef);
            } else {
                if(defined($res->json->{access_token})) {
                    return $cb->($self, undef, $res->json->{access_token});
                } else {
                    return $cb->($self, { type => 'KCException', message => 'NO_ACCESS_TOKEN' }, undef);
                }
            }
        } else {
            return $cb->($self, { type => 'KCException', message => 'KC_REQ_ERROR' }, undef);
        }
    });
}

sub validate_auth_nonce {
    my $self = shift;
    my $nonce = shift;
    my $cb = shift;

    $self->db->query('SELECT id FROM auth_nonce WHERE nonce = ?', $nonce => sub {
        my ($db, $err, $results) = (@_);

        if(defined($err)) {
            $self->redirect_root(status => 'error', 'error' => 'KC_NONCE_DB_ERROR');
        } else {
            if(my $nonce = $results->hash) {
                if($nonce->{used} > 0) {
                    $self->redirect_root(status => 'error', error => 'KC_NONCE_DUPLICATE');
                } else {
                    return $cb->($self);
                }
            } else {
                $self->redirect_root(status => 'error', error => 'KC_NONCE_NOT_FOUND');
            }
        }
    });
}

sub facebook_get_user_id_from_access_token {
    my $self = shift;
    my $token = shift;
    my $cb = shift;

    $self->ua->get('https://graph.facebook.com/debug_token' => form => {
        input_token     => $token,
        access_token    => $self->config('login')->{facebook}->{client_id},
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            if($res->json->{data}->{app_id} eq $self->config('login')->{facebook}->{client_id}) {
                return $cb->($self, undef, $res->json->{data}->{user_id});
            } else {
                return $cb->($self, 'FB_INVALID_APP', undef);
            }
        } else {
            return $cb->($self, 'KC_REQ_ERROR', undef);
        }
    });
}

sub facebook_get_user_profile {
    my $self = shift;
    my $uid  = shift;
    my $token = shift;

    $self->ua->get(sprintf('https://graph.facebook.com/v2.4/%s', $uid) => form => {
        access_token => $token,
        fields       => 'email,name',
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            # well, this should be fun! 
            $self->render(json => $res->json);
        } else {
            return $cb->($self, 'FB_COULD_NOT_GET_PROFILE', undef);
        }
    });
}

sub sign_in_user {
    my $self    = shift;
    my $email   = shift;
    my $cb      = shift;

}

sub facebook_return {
    my $self = shift;

    $self->render_later;
    
    if(my $error = $self->req->param('error')) {
        if($error eq 'access_denied') {
            $self->redirect_root(status => 'error', 'error' => 'FB_AUTH_DENIED_OR_CANCELLED');
        } else {
            $self->redirect_root(status => 'error', 'error' => 'FB_AUTH_ERROR');
        }
    } else {
        if(my $code = $self->req->param('code')) {
            if(my $nonce = $self->req->param('state')) {
                $self->validate_auth_nonce($nonce => sub {
                    my $self = shift; # only returns if the nonce is valid

                    $self->facebook_exchange_code_for_token($code => sub {
                        my ($self, $err, $token) = (@_);

                        if(defined($err)) {
                            # err is a hash, we just the message
                            $self->redirect_root(status => 'error', error => $err->{message});
                        } else {
                            # hurray, we have an access token, go debug it
                            $self->facebook_get_user_id_from_access_token($token => sub {
                                my ($self, $err, $user_id) = (@_);
        
                                if(defined($err)) {
                                    $self->redirect_root(status => 'error', error => $err);
                                } else {
                                    # grab the users' profile data
                                    $self->facebook_get_user_profile($user_id => $token => sub {
                                        my ($self, $err, $profile) = (@_);

                                        if(defined($err)) {
                                            $self->redirect_root(status => 'error', error => $err);
                                        } else {
                                            # finally... 
                                            $self->sign_in_user($profile->{email} => sub {
                                                my ($self, $err, $kc_token) = (@_);

                                                if(defined($err)) {
                                                    $self->redirect_root(status => 'error', error => $err);
                                                } else {
                                                    $self->redirect_root(status => 'ok', token => $kc_token);
                                                }
                                            });
                                        }
                                    });
                                }
                            });
                        }
                    });
                });
            } else {
                $self->redirect_root(status => 'error', 'error' => 'KC_NONCE_EMPTY');
            }
        } else {
            $self->redirect_root(status => 'error', 'error' => 'FB_NO_CODE');
        }
    }
}

1;
