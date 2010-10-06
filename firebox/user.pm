package user;
# vim:ts=4:sw=4:expandtab

use Moose;
use MooseX::AttributeHelpers;
use v5.10;

has 'mac' => (is => 'ro', isa => 'Str', required => 1);
has 'hostname' => (is => 'rw', isa => 'Str');
has 'ipv4_reachable' => (is => 'rw', isa => 'Int', default => 0);
has 'ipv6_reachable' => (is => 'rw', isa => 'Int', default => 0);

# Ein Array aus Positionen, zum Hinzufügen wird add_position benutzt
has '_ips' => (
    is => 'rw',
    metaclass => 'Collection::Array',
    isa => 'ArrayRef[Str]',
    auto_deref => 1,
    provides => {
        'push' => '_add_ip',
    'elements' => 'ips',
    },
    default => sub { [] }
);

# Add IP address if it is not already added
sub add_ip {
    my ($self, $ip) = @_;
    my @ips = $self->ips;
    return if $ip ~~ @ips;

    $self->_add_ip($ip);
}

1
