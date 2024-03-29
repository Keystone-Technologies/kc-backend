package Keystone::Plugin::Pg;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Pg;
use Mojo::Util qw/decamelize/;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    if(!defined($conf->{connection})) {
        $app->log->debug('It seems no Postgresql connection string has been supplied!');
    } else {
        $app->helper(pg => sub {
            state $pg = Mojo::Pg->new($conf->{connection});
        });
        $app->helper(db => sub {
            return shift->pg->db;
        });

        my $path = $app->home->rel_file($conf->{migration});
        $app->log->debug('Getting migration ' . decamelize(ref($app)) . ' from ' . $path);
        my $migration = $app->pg->migrations->name(decamelize(ref($app)))->from_file($path);

        if($migration->active < $migration->latest) {
            $app->log->info(ref($self) . ': Migrating to latest version');
            $migration->migrate;
        } else {
            $app->log->debug(ref($self) . ' No migration required');
        }
    }
}

1;
