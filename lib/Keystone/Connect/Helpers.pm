package Keystone::Connect::Helpers;
use strict;
use warnings;

sub install {
    my $dummy = shift;
    my $app   = shift;

    $app->helper(validate_tenant => sub {
        my $c   = shift;
        my $cb  = shift;

        # tenant must be passed in the kc_t parameter
        # cb receives $c, $error - error undef means the tenant is valid
        return $cb->($c, 'NO_TENANT_SUPPLIED') if(!defined($c->req->param('kc_t')));

        $c->pg->db->query('SELECT t.*,tm.hostname FROM tenant t, tenant_map tm WHERE tm.tenant=t.id AND tm.hostname = ?', $c->req->param('kc_t') => sub {
            my ($db, $err, $results) = (@_);

            if(defined($err) || $results->rows == 0) {
                return $cb->($c, 'INVALID_TENANT');
            } else {
                $self->stash(tenant => $results->hash);
                return $cb->($c, undef);
            }
        });
    });
    $app->helper(url_on_tentant => sub {
    });
    $app->helper(return_to_tenant => sub {
    });
}

1;
