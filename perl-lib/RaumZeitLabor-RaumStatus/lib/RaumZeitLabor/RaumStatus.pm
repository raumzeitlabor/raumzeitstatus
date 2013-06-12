use v5.14;
use utf8;
package RaumZeitLabor::RaumStatus 0.2;

# not in core
use AnyEvent::HTTP;
use JSON::XS;
use Method::Signatures::Simple;

sub d {
    my $msg = scalar localtime;
    $msg .= ' ' . shift if @_ == 1;
    $msg .= "\n\t" . join"\n\t", @_ if @_;
    STDERR->print("$msg\n");
    return;
}

use Moose;

has url => (is => 'ro', default => 'http://s.rzl.so/api/stream/full.json');

has door => (is => 'rw');

my @array_attr = (
    traits => ['Array'], default => sub { [] }, auto_deref => 1
);
has _raw_members => (
    is => 'rw', @array_attr,
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

around 'set_members' => func ($orig, $self, $_members) {
    my @members = sort @$_members;
    my @before = sort $self->_raw_members;
    my @timeouts = sort $self->members_timeout;

    # do nothing if nothing has changed
    return if @members ~~ @before;

    d("set_member: @members",
        "before: @before",
        "timeouts: @timeouts");

    $self->$orig(\@members);

    if (my @joined = grep { not $_ ~~ @before } @members) {
        d("joined: @joined");
        $self->destroy_timeout($_) for @joined;

        # don't call join callbacks for aborted timeouts
        @joined = grep { not $_ ~~ @timeouts } @joined;

        if (@joined) {
            d("calling join_cb for: @joined");
            $self->$_(@joined) for $self->join_cb;
        }
    }

    my @parted = grep { not $_ ~~ @timeouts }
                 grep { not $_ ~~ @members }
                 @before;
    my $timeout = $self->flapping_timeout;
    for my $member (@parted) {
        d("timeout, add timer for: $member");
        $self->add_timeout(
            $member => AnyEvent->timer(after => $timeout, cb => sub {
                    $self->destroy_timeout($member);
                    d("calling part_cb for $member");
                    $self->$_($member) for $self->part_cb;
            }),
        );
    }
};

method BUILD { $self->_connect }

method feed_jsonstring ($data) {
    my $pkt = eval { decode_json($data) };
    if (not $pkt) {
        d('bad json:', $data);
        return;
    }
    my $members = $pkt->{details}{laboranten} || [];
    $self->set_members($members);
}

method _connect {
    my $url = $self->url;
    state $reconnect;
    http_get $url, on_body => func ($data, $header) {
        # it is a keep-alive packet, keep reading
        return 1 if $data eq "\r\n";

        $self->feed_jsonstring($data);

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
