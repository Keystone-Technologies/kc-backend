package Keystone::Connect::Controller::Api::V1;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw/decode_json encode_json/;

sub me_set_grid {
    my $self = shift;

    $self->render_later;
   
    $self->db->query('SELECT json_data FROM account_json WHERE account = ? AND tenant = ?', $self->current_user->{id}, $self->current_tenant->{id} => sub {
        my ($db, $err, $res) = (@_);

        if(defined($err)) {
            $self->render(json => { status => 'error', error => 'KC_DATABASE_ERROR' });
        } else {
            if($res->rows == 0) {
                $self->db->query('INSERT INTO account_json (account, tenant, json_data) VALUES (?, ?, ?)', $self->current_user->{id}, $self->current_tenant->{id}, encode_json($self->req->json) => sub {
                    my ($db, $err, $res) = (@_);

                    if(defined($err)) {
                        $self->render(json => { status => 'error', error => 'KC_DATABASE_ERROR' });
                    } else {
                        $self->render(json => { status => 'ok', data => $self->req->json });
                    }
                });
            } else {
                $self->db->query('UPDATE account_json SET json_data = ? WHERE account = ? AND tenant = ?', encode_json($self->req->json), $self->current_user->{id}, $self->current_tenant->{id} => sub {
                    my ($db, $err, $res) = (@_);

                    if(defined($err)) {
                        $self->render(json => { status => 'error', error => 'KC_DATABASE_ERROR' });
                    } else {
                        $self->render(json => { status => 'ok', data => $self->req->json });
                    }
                });
            }
        }
    });
}

sub me_get_grid {
    my $self = shift;
    
    $self->render_later;
    $self->db->query('SELECT json_data FROM account_json WHERE account = ? AND tenant = ?', $self->current_user->{id}, $self->current_tenant->{id} => sub {
        my ($db, $err, $res) = (@_);

        if(defined($err)) {
            $self->render(json => { status => 'error', error => 'KC_DATABASE_ERROR' });
        if(my $data = $res->hash) {
            # a bit superfluous to encode/decode but hey, it makes sure it goes out correctly
            $self->render(json => { status => 'ok', data => encode_json(decode_json($data->{json_data})) });
        } else {
            $self->render(json => { status => 'error', error => 'KC_DATABASE_ERROR' });
        }
    });
}

1;
