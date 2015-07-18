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
            $self->db->query('INSERT INTO auth_nonce (nonce) VALUES (?)', $nonce => sub {
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
    $self->generate_nonce(sub {
        my $c = shift;
        my $nonce = shift;

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

sub facebook_return {
    my $self = shift;

    $self->render_later;

    if(defined($self->req->param('error'))) {
        # we could log this, but at the moment we'll just throw out the javascript to close the popup 
        # window and reload the opener
        $self->render(template => 'auth/close', format => 'js');
    } elsif(my $token = $self->req->param('token')) {
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
                    # FIXME: persistent server side session perhaps? 
                }
            }
        });
    } else {
        # no code, no error, generally classified as: wtf? 
        # close the auth window and reload the caller
        $self->render(template => 'auth/close', format => 'js');
    }
}

1;
