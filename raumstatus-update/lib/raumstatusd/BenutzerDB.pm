package raumstatusd::BenutzerDB;

use strict; use warnings;
use v5.14;

use DBIx::Simple;
use SQL::Abstract;
use Log::Log4perl qw/:easy/;

use Moo;

has 'db' => (
    is => 'rwp',
    lazy => 1,
    builder => '_build_db_connection',
);

has 'config' => (
    is => 'ro',
    default => sub { $raumstatusd::Instance->config->{db} },
);

sub _build_db_connection {
    my ($self) = @_;

    my $config = $self->config;
    my $dbix_simple = DBIx::Simple->connect(
        $config->{uri}, $config->{user}, $config->{pass}
    );

    return $dbix_simple;
}

sub run {
    my ($self, $pipe) = @_;

    my $db = $self->db;

    async {
        while (my $stations = $pipe->get) {
            $db->begin_work;
            $db->query('DELETE FROM leases');

            for my $station (@$stations) {
                $self->update_benutzerdb_lease($station);
            }

            $db->commit;
        }
    };

    return $self;
}

sub internal_status {
    my ($self) = @_;

    my $db = $self->db;

    my @macs = $db->select(
        'leases', 'mac', {
            ipv4_reachable => 1
        },
    )->flat;

    my @members = $db->select(
        'devices', 'DISTINCT handle', {
            mac => { -in => \@macs }
        }
    )->flat;

    INFO('laboranten: ' . join ', ', @members);

    my %status = (
        details => {
            geraete => scalar @macs,
            laboranten => \@members,
        }
    );

    return \%status;
}

sub update_benutzerdb_lease {
    my ($self, $station) = @_;

    my $db = $self->db;

    # TODO: handle multiple IPs
    $db->insert(
        'leases', {
            ip             => $station->{ip},
            mac            => $station->{mac},
            ipv4_reachable => 1,
            ipv6_reachable => 0,
            hostname       => $station->{hostname}
        }
    );

    # update last seen (TODO: ipv6)
    $db->update(
        'devices',
        { lastseen => $station->{last_seen} },
        {
            mac => $station->{mac},
            updatelastseen => 1
        }
    );
}

1;
