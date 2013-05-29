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
    is => 'rw', traits => ['Array'], default => sub { [] }, auto_deref => 1
);
has _raw_members => (
    @array_attr,
    writer => 'set_members',
    handles => { members => 'elements' },
);
has join_cb => (
    @array_attr,
    handles => { register_join => 'push' },
);
has part_cb => (
    @array_attr,
    handles => { register_part => 'push' },
);

around 'set_members' => func ($orig, $self, $members) {
    my @before = $self->members;
    say "before: @before";
    if (my @joined = grep { not $_ ~~ @before } @$members) {
        say "joined: @joined";
        $self->$_(@joined) for $self->join_cb;
    }
    if (my @parted = grep { not $_ ~~ @$members } @before) {
        say "parted: @parted";
        $self->$_(@parted) for $self->part_cb;
    }

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
