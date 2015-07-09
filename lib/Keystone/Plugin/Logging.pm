package Keystone::Plugin::Logging;
use Mojo::Base 'Mojolicious::Plugin';

sub _fix_args_list {
    my @list = ();

    foreach my $entry (@_) {
        if(defined($entry)) {
            push(@list, $entry);
        } else {
            push(@list, 'undef');
        }
    }
    return @list;
}

sub register {
    my $self = shift;
    my $app  = shift;

    $app->helper(debug => sub {
        my $self = shift;
        $self->app->log->debug(join(' ', _fix_args_list(@_)));
    });
    $app->helper(error => sub {
        my $self = shift;
        $self->app->log->error(join(' ', _fix_args_list(@_)));
    });
    $app->helper(warning => sub {
        my $self = shift;
        $self->app->log->warning(join(' ', _fix_args_list(@_)));
    });
    $app->helper(info => sub {
        my $self = shift;
        $self->app->log->info(join(' ', _fix_args_list(@_)));
    });
    $app->helper(fatal => sub {
        my $self = shift;
        $self->app->log->fatal(join(' ', _fix_args_list(@_)));
    });
}

1;
