package raumstatusd;
use raumstatusd::base;

our $Instance;

use raumstatusd::BenutzerDB;
use raumstatusd::Update;
use raumstatusd::Unifi;

use EV;
use Coro;
use AnyEvent;
# initialize AnyEvent as soon as possible to make
# sure integration of EV/Coro/AnyEvent works as expected.
BEGIN { AnyEvent::detect; }

has 'config' => (
    is => 'ro',
    default => sub { _load_config("$ENV{HOME}/raumstatus_config.json") },
);

has 'main_queue' => (
    is => 'ro',
    default => sub { Coro::Channel->new },
);

=head1 NAME

raumstatusd - The great new raumstatusd!

=head1 VERSION

Version 0.0.001

=cut

our $VERSION = '0.000.001';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

=cut

sub run {
    my ($self) = @_;
    $Instance = $self;

    my $db = raumstatusd::BenutzerDB->new;

    my $unifi = raumstatusd::Unifi->new->run;

    while (my $event = $self->main_queue->get) {
        if ($event->isa('raumstatusd::Unifi::Event')) {
            say "macs: @{ $event->macs }"
        }
    }

}

sub _load_config {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Could not open config file: $file\n";

    # allow comments and trailing commata in lists
    my $json = JSON::XS->new->relaxed(1);

    my $config = $json->decode(do { local $/; <$fh> });

    for my $module (qw/unifi status db/) {
        die "config for $module does not exist."
            unless exists $config->{$module};

        die "config for $module is incomplete"
            unless 3 == grep { $config->{$module}{$_} }
                            qw/uri user pass/;
    }

    return $config;
}

1;
__END__

=head1 AUTHOR

Maik Fischer, C<< <maikf at qu.cx> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-raumzeitlabor-status-update at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RaumZeitLabor-Status-Update>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc raumstatusd::Update


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RaumZeitLabor-Status-Update>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RaumZeitLabor-Status-Update>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RaumZeitLabor-Status-Update>

=item * Search CPAN

L<http://search.cpan.org/dist/RaumZeitLabor-Status-Update/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Maik Fischer.

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/BSD-3-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of Maik Fischer's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

# vim: set ts=4 sw=4 sts=4 expandtab:
