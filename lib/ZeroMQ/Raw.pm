package ZeroMQ::Raw;
use strict;
use warnings;
use XSLoader;
use XS::Object::Magic;
use 5.008;

our $VERSION = '0.00_01';

XSLoader::load('ZeroMQ::Raw', $VERSION);

require ZeroMQ::Raw::Context;

1;

__END__

=head1 AUTHOR

Jonathan Rockway C<< <jrockway@cpan.org> >>
