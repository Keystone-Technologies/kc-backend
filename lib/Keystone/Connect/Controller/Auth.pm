package Keystone::Connect::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/url_escape b64_encode dumper/;

# this module serves as a base class for the respective auth 
# modules now

sub signout {
    my $self = shift;
    my $r    = $self->req->param('r');

    $self->render_later;

    if(defined($self->session('kc_token'))) {
        $self->db->query('DELETE FROM backend_token WHERE token = ?', $self->session('kc_token') => sub {
            $self->session(kc_token => undef);
            $self->redirect_to($r);
        });
    } else {
        $self->session(kc_token => undef);
        $self->redirect_to($r);
    }
}

sub validate_kc_token {
    my $self = shift;

    $self->debug('validate_kc_token(): entered');

    if(defined($self->session('kc_token'))) {
        $self->debug('validate_kc_token(): have token in session: ', $self->session('kc_token'));
        $self->db->query('SELECT a.name,a.email FROM account a, tenant t, backend_token bt WHERE t.id = a.tenant AND a.id = bt.account AND bt.token = ?', $self->session('kc_token') => sub {
            my ($db, $err, $res) = (@_);

            if(defined($err) || $res->rows == 0) {
                $self->debug('validate_kc_token(): lookup failed, error: ', $err, ' rowcount: ', $res->rows);
                # error or no result == invalid
                $self->render(json => { status => 'error', error => 'KC_TOKEN_INVALID' });
            } elsif(my $account = $res->hash) {
                $self->debug('validate_kc_token(): account hash: ', dumper($account));
                # FIXME: check token expiry here, for now just set things and continue
                $self->stash('current_user' => $account);
                $self->continue;
            } else {
                $self->debug('validate_kc_token(): account hash not present');
                $self->render(json => { status => 'error', error => 'KC_NO_ACCOUNT' });
            }
        });
    } else {
        $self->debug('validate_kc_token(): no token in session');
        return 1;
    }
    return undef;
}

sub generate_nonce {
    my $self    = shift;
    my $check   = shift;
    my $cb      = shift;
    my @a       = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);

    # could be done with Data::UUID but then again, that's just another dependency that
    # we don't really want 
    my $nonce = '';
    my $now   = time() + 0;

    $nonce .= $a[$_] for(split(//, $now));

    while(length($nonce) < 48) {
        $nonce .= $a[int(rand(scalar(@a)))];
    }

    return $cb->($self, $nonce) unless($check > 0);

    $self->db->query('SELECT id FROM auth_nonce WHERE nonce = ?', $nonce => sub {
        my ($db, $err, $results) = (@_);

        if($results->rows == 0) {
            $self->db->query('INSERT INTO auth_nonce (nonce, used) VALUES (?, 0)', $nonce => sub {
                return $cb->($self, $nonce);
            });
        } else {
            # it exists already, which is a bit of a pain, so let's do this again. 
            # yes, there is a chance that this can recurse in a hideous fashion...
            return $self->generate_nonce($cb, $check);
        }
    });
}

sub redirect_root {
    my $self = shift;
    my %args = (@_);

    my $root = $self->session('auth')->{root};
    $self->session('auth' => undef);
   
    if($args{status} eq 'error') {
        $self->redirect_to(sprintf('%s?status=error&error=%s', $root, $args{error}));
    } else {
        $self->redirect_to(sprintf('%s?status=ok&token=%s', $root, $args{token}));
    }
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

sub create_new_account {
    my $self    = shift;
    my $profile = shift;
    my $cb      = shift;

    $self->debug('create_new_account(): entered');

    $self->db->query('INSERT INTO account (name, email, tenant) VALUES (?, ?, ?) RETURNING id', @{$profile}{qw/name email tenant/} => sub {
        my ($db, $err, $res) = (@_);

        if(defined($err)) {
            $self->debug('create_new_account(): error: ', $err);
            return $cb->($self, $err, undef);
        } else {
            $self->debug('create_new_account(): ok: ', $res->{id});
            return $cb->($self, undef, $res->{id});
        }
    });
}

sub generate_backend_token {
    my $self       = shift;
    my $account_id = shift;
    my $cb         = shift;

    $self->debug('generate_backend_token(): entered for account_id: ', $account_id);

    # the backend token is comprised of the account_id, a colon, then a nonce 
    $self->generate_nonce(0 => sub {
        my ($self, $nonce) = (@_);
    
        $self->debug('generate_backend_token(): generated token: ', $nonce);

        $self->db->query('INSERT INTO backend_token (token, account) VALUES (?, ?) RETURNING token', $nonce, $account_id => sub {
            my ($db, $err, $res) = (@_);

            if(defined($err)) {
                $self->debug('generate_backend_token(): store error: ', $err);
                return $cb->($self, $err, undef);
            } else {
                $self->debug('generate_backend_token(): store ok');
                return $cb->($self, undef, $nonce);
            }
        });
    });
}

sub sign_in_user {
    my $self    = shift;
    my $profile = shift;
    my $cb      = shift;

    $self->debug('sign_in_user(): entered with profile ', dumper($profile));

    $self->db->query('SELECT id FROM account WHERE email = ? AND tenant = ?', $profile->{email}, $self->session('auth')->{tenant} => sub {
        my ($db, $err, $res) = (@_);

        if(defined($err)) {
            return $cb->($self, 'KC_DATABASE_ERROR', undef);
        } else {
            # fix the profile
            $profile->{tenant} = $self->session('auth')->{tenant};
            if($res->rows == 0) {
                # new account, so create that first
                $self->create_new_account($profile => sub {
                    my ($self, $err, $account_id) = (@_);

                    if(defined($err)) {
                        return $cb->($self, 'KC_ACCOUNT_CREATE_ERROR', undef);
                    } else {
                        $self->generate_backend_token($account_id => sub {
                            my ($self, $err, $token) = (@_);

                            if(defined($err)) {
                                return $cb->($self, 'KC_TOKEN_CREATE_ERROR', undef);
                            } else {
                                return $cb->($self, undef, $token);
                            }
                        });
                    }
                });
            } else {
                my $account = $res->hash;

                $self->generate_backend_token($account->{id} => sub {
                    my ($self, $err, $token) = (@_);

                    if(defined($err)) {
                        return $cb->($self, 'KC_TOKEN_CREATE_ERROR', undef);
                    } else {
                        return $cb->($self, undef, $token);
                    }
                });
            }
        }
    });
}

1;
