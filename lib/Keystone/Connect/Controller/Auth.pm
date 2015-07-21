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

    $self->render_later;

    $self->validate_tenant(sub {
        my ($c, $err) = (@_);

        if(defined($err)) {
            # return to the tenant url
            $c->stash(is_error => 1, error => $err);
        } else {
            $c->session(auth => { return => $self->req->param('auth_return'), tenant => $self->stash('tenant')->{id}  });
            $c->render_later;
            $c->generate_nonce(sub {
                my ($c, $nonce) = (@_);

                my $return_url = sprintf('%s/auth/facebook_return', $c->req->url->base);

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

sub facebook_return {
    my $self = shift;

    $self->render_later;

    if(defined($self->req->param('error'))) {
        $self->stash(is_error => 1, error => $self->req->param('error'));
        $self->render(template => 'auth/close');
    } elsif(my $nonce = $self->req->param('#state')) {
        # see if the nonce has been used yet
        $self->db->query('SELECT id FROM auth_nonce WHERE nonce = ?', $nonce => sub {
            my ($db, $err, $results) = (@_);

            if(my $nonce = $results->hash) {
                if($nonce->{used} > 0) {
                    $self->stash(is_error => 1, error => 'NONCE_ALREADY_USED');
                    $self->render(template => 'auth/close');
                } elsif(my $token = $self->req->param('access_token')) {
                    $self->ua->get('https://graph.facebook.com/debug_token' => form => {
                        input_token     => $token,
                        access_token    => $self->config('login')->{facebook}->{client_id},
                    } => sub {
                        my ($ua, $tx) = (@_);

                        if(my $res = $tx->success) {
                            if($res->json->{data}->{app_id} eq $self->config('login')->{facebook}->{client_id}) {
                                # fetch email address using the graph API, then exchange it for an ID from the database
                                # if we have one, and create something if we don't have it
                            } else {
                                $self->stash(is_error => 1, error => 'FB_INVALID_APP_ID');
                                $self->render(template => 'auth/close');
                            }
                        }
                    });
                } else {
                    $self->stash(is_error => 1, error => 'FB_NO_TOKEN_RETURNED');
                    $self->render(template => 'auth/close');
                }
            } else {
                $self->stash(is_error => 1, error => 'NONCE_INVALID');
                $self->render(template => 'auth/close');
            }
        });
    } else {
        $self->stash(is_error => 1, error => 'NONCE_EMPTY');
        $self->render(template => 'auth/close');
    }
}

1;
