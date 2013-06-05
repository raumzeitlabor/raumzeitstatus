use v5.14;
use utf8;
package RaumZeitLabor::RaumStatus 0.1;

# not in core
use AnyEvent::HTTP;
use JSON::XS;
use Method::Signatures::Simple;

use Moose;

has url => (is => 'ro', default => 'http://s.rzl.so/api/stream/full.json');

has door => (is => 'rw');

my @array_attr = (
    traits => ['Array'], default => sub { [] }, auto_deref => 1
);
has _raw_members => (
    is => 'ro', @array_attr,
    writer => 'set_members',
    handles => { members => 'elements' },
);
has _members_timeout => (
    is => 'ro', traits => ['Hash'], default => sub { {} },
    handles => {
        members_timeout => 'keys',
        destroy_timeout => 'delete',
        exists_timeout => 'exists',
        add_timeout => 'set',
    },
);

around 'members' => func ($orig, $self) {
    my @m = $self->$orig();
    push @m, $self->members_timeout;
    return @m
};

# since smartphones regularly disconnect from wlan,
# only call the part callbacks after a timeout,
# choose 60 seconds (+ 5% difference)
has flapping_timeout => (
    is => 'rw',
    default => 63,
);

has join_cb => (
    is => 'rw', @array_attr,
    handles => { register_join => 'push' },
);

has part_cb => (
    is => 'rw', @array_attr,
    handles => { register_part => 'push' },
);

around 'set_members' => func ($orig, $self, $members) {
    my @before = $self->_raw_members;
    # say "@$members";

    my @timeouts = $self->members_timeout;

    if (my @joined = grep { not $_ ~~ @before } @$members) {
        $self->destroy_timeout(@joined);

        # don't call join callbacks for aborted timeouts
        @joined = grep { not $_ ~~ @timeouts } @joined;

        $self->$_(@joined) for $self->join_cb;
    }

    my @parted = grep { not $_ ~~ @timeouts }
                 grep { not $_ ~~ @$members }
                 @before;
    my $timeout = $self->flapping_timeout;
    for my $member (@parted) {
        $self->add_timeout(
            $member => AnyEvent->timer(after => $timeout, cb => sub {
                    $self->$_($member) for $self->part_cb;
            }),
        );
    }

    # say "timeout: @{[ $self->members_timeout ]}";
    $self->$orig($members);

};

method BUILD { $self->_connect }

method _connect {
    my $url = $self->url;
    state $reconnect;
    http_get $url, on_body => func ($data, $header) {
        # it is a keep-alive packet, keep reading
        return 1 if $data eq "\r\n";

        my $pkt = eval { decode_json($data) };
        if (not $pkt) {
            warn "bad data: '$data'\n";
            return 1; # but keep on reading
        }
        $self->set_members($pkt->{details}{laboranten} || []);

        return 1; # read more data
    }, sub {
        warn "disconnected";
        # connection is closed for whatever reason, open a new one after some delay
        $reconnect = AnyEvent->timer(after => 3, cb => sub { $self->_connect });
    };

    return;
}

__PACKAGE__->meta->make_immutable;
1;
# vim: set ts=4 sw=4 sts=4 expandtab: 
