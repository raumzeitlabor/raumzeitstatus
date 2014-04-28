package RaumZeitLabor::RaumStatus 0.2;
use v5.14;
use utf8;

# not in core
use AnyEvent::HTTP;
use JSON::XS;

use Moose;
no if $] >= 5.018, warnings => "experimental::smartmatch";

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

around 'members' => sub {
    my ($orig, $self) = @_;
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

has disconnect_cb => (
    is => 'rw', @array_attr,
    handles => { register_disconnect => 'push' },
);

around 'set_members' => sub {
    my ($orig, $self, $_members) = @_;
    my @members = sort @$_members;
    my @before = sort $self->_raw_members;
    my @timeouts = sort $self->members_timeout;

    # do nothing if nothing has changed
    return if @members ~~ @before;

    $self->log(debug => "set_member: '@members' before: '@before' timeouts: '@timeouts'");

    $self->$orig(\@members);

    if (my @diff = grep { not $_ ~~ @before } @members) {
        my @joined = grep { not $_ ~~ @timeouts } @diff;
        $self->log(debug => "joined: @joined");

        my @canceled_timeouts = grep { $_ ~~ @timeouts } @diff;
        $self->destroy_timeout($_) for @canceled_timeouts;

        if (@joined) {
            $self->log(debug => "calling join_cb for: @joined");
            $_->(@joined) for $self->join_cb;
        }
    }

    # update timeouts, because we may have invalided some
    @timeouts = sort $self->members_timeout;

    my @parted = grep { not $_ ~~ @timeouts }
                 grep { not $_ ~~ @members }
                 @before;
    my $timeout = $self->flapping_timeout;
    for my $member (@parted) {
        $self->log(debug => "timeout, add timer for: $member");
        $self->add_timeout(
            $member => AnyEvent->timer(after => $timeout, cb => sub {
                    $self->destroy_timeout($member);
                    $self->log(debug => "calling part_cb for $member");
                    $_->($member) for $self->part_cb;
            }),
        );
    }
};

no Moose;
__PACKAGE__->meta->make_immutable;

sub BUILD {
    my ($self) = @_;

    $self->_connect;
}

sub _parse_json {
    my ($self, $data) = @_;
    my $pkt = eval { decode_json($data) };
    if (not $pkt) {
        $self->log(critical => 'bad json:', $data);
        return;
    }
    my $members = $pkt->{details}{laboranten} || [];
    $self->set_members($members);
}

sub _connect {
    my ($self) = @_;
    my $url = $self->url;
    state $reconnect;
    http_get $url, on_body => sub {
        my ($partial, $header) = @_;
        # it is a keep-alive packet, keep reading
        return 1 if $partial eq "\r\n";

        $self->_parse_json($partial);

        return 1; # read more data
    }, sub {
        # connection closed for whatever reason, reconnect after a bit
        $self->log(critical => 'disconnected from streaming RaumStatus API');
        $reconnect = AnyEvent->timer(after => 3, cb => sub { $self->_connect });
        # invalidate members
        $self->set_members([]);
        $_->() for $self->disconnect_cb;
    };

    return;
}

sub log {
    my ($self, $level, $msg) = @_;
    say "$level: $msg";
    return;
}

1;
# vim: set ts=4 sw=4 sts=4 expandtab: 
