package Keystone::Connect::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub validate_tenant {
    my $self = shift;
    my $cb   = shift;

    # tenant must be passed in the kc_t parameter
    # cb receives $c, $error - error undef means the tenant is valid
    return $cb->($self, 'NO_TENANT_SUPPLIED') if(!defined($self->req->param('kc_t')));

    $self->pg->db->query('SELECT t.* FROM tenant t, tenant_map tm WHERE tm.tenant=t.id AND tm.hostname = ?', $self->req->param('kc_t') => sub {
        my ($db, $err, $results) = (@_);

        if(defined($err) || $results->rows == 0) {
            return $cb->($self, 'INVALID_TENANT');
        } else {
            $self->stash(tenant => $results->hash);
            return $cb->($self, undef);
        }
    });
}

1;
