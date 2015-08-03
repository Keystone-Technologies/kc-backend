package Keystone::Connect::Helpers;
use strict;
use warnings;
use Mojo::JSON qw/encode_json decode_json/;
use Mojo::Util qw/dumper/;

sub install {
    my $dummy = shift;
    my $app   = shift;

    $app->helper(validate_tenant => sub {
        my $c   = shift;
        my $cb  = shift;

        return $cb->($c, 'NO_TENANT_SUPPLIED') if(!defined($c->req->param('kc_t')));

        # see if we have a kc_t parameter; this will contain the tenant - if there's no tenant, but 
        # we do have an uid in the session, see if the session contains the tenant ID - and then check
        # that the tenant still exists
        if(defined($c->req->param('kc_t'))) {
            # tenant parameter, will override everything else 
        }

        $c->pg->db->query('SELECT t.*,tm.hostname FROM tenant t, tenant_map tm WHERE tm.tenant=t.id AND tm.hostname = ?', $c->req->param('kc_t') => sub {
            my ($db, $err, $results) = (@_);

            if(defined($err) || $results->rows == 0) {
                return $cb->($c, 'INVALID_TENANT');
            } else {
                $c->stash(tenant => $results->hash);
                return $cb->($c, undef);
            }
        });
    });
    $app->helper(get_user_for_js => sub {
        my $self = shift;
        return (defined($self->user)) ? encode_json($self->user) : 'null';
    });
    $app->helper(get_backend_url => sub { return shift->req->url->base });
    $app->helper(user => sub { return shift->stash('current_user') });
    $app->helper(url_on_tentant => sub {
    });
    $app->helper(return_to_tenant => sub {
    });
}

1;
