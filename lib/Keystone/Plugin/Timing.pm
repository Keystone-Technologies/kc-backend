package Keystone::Plugin::Timing;
use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes qw/gettimeofday tv_interval/;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->hook(before_dispatch => sub {
        my $c = shift;
        $c->stash('timing' => { start => [ gettimeofday ], hooks => {}, items => {} });
    });
    
    $app->hook(after_static => sub {
        my $c = shift;
        $c->stash('timing')->{hooks}->{after_static} = tv_interval($c->stash('timing')->{start});
    });

    $app->hook(before_routes => sub {
        my $c = shift;
        $c->stash('timing')->{hooks}->{before_routes} = tv_interval($c->stash('timing')->{start});
    });

    $app->hook(around_action => sub {
        my ($next, $c, $action, $last) = (@_);
        $c->stash('timing')->{hooks}->{around_action} = tv_interval($c->stash('timing')->{start});
        return $next->();
    });

    $app->helper(timing_start_item => sub {
        my $self = shift;
        my $item = shift;

        $self->stash('timing')->{items_p}->{$item} = [ gettimeofday ];
    });

    $app->helper(timing_end_item => sub {
        my $self = shift;
        my $item = shift;

        return unless(defined($self->stash('timing')->{items_p}->{$item}));

        my $elapsed = tv_interval($self->stash('timing')->{items_p}->{$item});

        if(defined($self->stash('timing')->{items}->{$item})) {
            $self->stash('timing')->{items}->{$item} += delete($self->stash('timing')->{items_p}->{$item});
        } else {
            $self->stash('timing')->{items}->{$item} = delete($self->stash('timing')->{items_p}->{$item});
        }
    });

    $app->helper(timing_get_item => sub {
        my $self = shift;
        my $item = shift;

        return $self->stash('timing')->{items}->{$item};
    });

    $app->helper('full_timing_list' => sub {
        my $self = shift;
        my $l    = [];

        for(qw/after_static before_routes around_action/) {
            push(@$l, sprintf('hook: %s: %.4f', $_, $self->stash('timing')->{hooks}->{$_}));
        }
        foreach my $item (keys(%{$self->stash('timing')->{items}})) {
            push(@$l, sprintf('item: %s: %.4f', $item, $self->stash('timing')->{items}->{$item}));
        }
            
        push(@$l, sprintf('total: %.4f', $self->stash('timing')->{elapsed}));
        return join(', ', @$l);
    });

    $app->hook(before_render => sub {
        my ($c, $args) = (@_);
        $c->stash('timing')->{elapsed}  = tv_interval($c->stash('timing')->{start}));
    });
}

1;
