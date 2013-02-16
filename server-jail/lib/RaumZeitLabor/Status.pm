# vim:ts=4:sw=4:expandtab
package RaumZeitLabor::Status;

use strict;
use v5.10;
our $VERSION = '0.01';

use Tatsumaki::Application;
use Tatsumaki::Handler;

# Handlers
use RaumZeitLabor::Status::Handler::Full;
use RaumZeitLabor::Status::Handler::Stream::Full;
use RaumZeitLabor::Status::Handler::Simple;
use RaumZeitLabor::Status::Handler::Update;

=head1 NAME

RaumZeitLabor::Status - Der RaumZeitLabor Status-Handler.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Wird über Initscript gestartet.

=cut

sub webapp {
    my $class = shift;

    my $app = Tatsumaki::Application->new([
        '/api/full.json' => 'RaumZeitLabor::Status::Handler::Full',
        '/api/stream/full.json' => 'RaumZeitLabor::Status::Handler::Stream::Full',
        '/api/simple(|.txt)' => 'RaumZeitLabor::Status::Handler::Simple',
        '/api/update' => 'RaumZeitLabor::Status::Handler::Update',
    ]);

    $app->psgi_app;
}

=head1 AUTHOR

Michael Stapelberg C<< <michael@stapelberg.de> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-raumzeitlabor-status at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RaumZeitLabor-Status>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RaumZeitLabor::Status


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RaumZeitLabor-Status>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RaumZeitLabor-Status>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RaumZeitLabor-Status>

=item * Search CPAN

L<http://search.cpan.org/dist/RaumZeitLabor-Status/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Michael Stapelberg.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


=cut

1; # End of RaumZeitLabor::Status
