use strict;
use warnings;
use inc::Module::Install;
use ExtUtils::Depends;

mkdir 'build';
my $pkg = ExtUtils::Depends->new( 'ZeroMQ::Raw', 'XS::Object::Magic' );


my $extra_inc = $ENV{ZMQ_INCLUDE} || $ENV{ZMQ} ? $ENV{ZMQ}.'/include' : '';
my $extra_lib = $ENV{ZMQ_LIB}     || $ENV{ZMQ} ? $ENV{ZMQ}.'/lib'     : '';
$extra_lib .= ' ' if $extra_lib;
$extra_lib .= '-lzmq';

$pkg->set_inc($extra_inc);
$pkg->set_libs($extra_lib);
$pkg->add_xs('RawZMQ.xs');
$pkg->add_c('zmqxs.c');
$pkg->add_pm(
    './lib/ZeroMQ/Raw.pm'           => '$(INST_LIBDIR)/Raw.pm',
    './lib/ZeroMQ/Raw/Context.pm'   => '$(INST_LIBDIR)/Raw/Context.pm',
    './lib/ZeroMQ/Raw/Message.pm'   => '$(INST_LIBDIR)/Raw/Message.pm',
    './lib/ZeroMQ/Raw/Constants.pm' => '$(INST_LIBDIR)/Raw/Constants.pm',
    './lib/ZeroMQ/Raw/Socket.pm'    => '$(INST_LIBDIR)/Raw/Socket.pm',
);
$pkg->add_typemaps('typemap');
$pkg->save_config('build/IFiles.pm');

# use DDS;
# warn Dump({$pkg->get_makefile_vars});
makemaker_args(
    $pkg->get_makefile_vars,
);

name 'ZeroMQ-Raw';
license 'LGPL';
all_from 'lib/ZeroMQ/Raw.pm';
ppport;

configure_requires 'ExtUtils::Depends';
configure_requires 'XS::Object::Magic';
requires 'XS::Object::Magic';
test_requires 'Test::More';
test_requires 'Test::Exception';

WriteAll;
