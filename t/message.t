use strict;
use warnings;
use Test::More;
use Test::Exception;
use Devel::Peek qw(Dump SvREFCNT);

use ZeroMQ::Raw;

# new empty message, will get buffer at a later date
{
    my $empty;
    lives_ok {
        $empty = ZeroMQ::Raw::Message->new;
    } 'creating empty message lives';

    ok $empty->is_allocated, 'allocated the underlying msg object ok';

    ok !$empty->data, 'no data';

    lives_ok {
        undef $empty;
    } 'deallocates ok';
}

# new empty buffer
{
    my $from_size;
    lives_ok {
        $from_size = ZeroMQ::Raw::Message->new_from_size(1024);
    } 'allocating message of size 1024 works';

    ok $from_size->is_allocated, 'allocated ok';
    is $from_size->size, 1024, 'size is what we expect';

    lives_ok {
        undef $from_size;
    } 'deallocates ok';
}

# new from scalar
{
    my $scalar = "foo bar";
    is SvREFCNT($scalar), 1, 'baseline refcnt';

    my $from_scalar;
    lives_ok {
        $from_scalar = ZeroMQ::Raw::Message->new_from_scalar($scalar);
    } 'creating msg from scalar works';

    is SvREFCNT($scalar), 2, 'refcnt increased ok';

    ok $from_scalar->is_allocated, 'allocated ok';
    is $from_scalar->size, 7, 'got correct size';
    is $from_scalar->data, 'foo bar', 'got correct data';

    is SvREFCNT($from_scalar), 1, 'message has refcnt of 1';
    {
        # test zero-copy
        my $not_copied;
        $from_scalar->data_nocopy($not_copied);
        is $not_copied, 'foo bar', 'got correct data';
        is SvREFCNT($from_scalar), 2, 'message gets refcnt++';

        # changing scalar changes not_copied
        $scalar =~ s/foo/goo/;

        is $not_copied, 'goo bar', 'got new data (!)';
    }
    is SvREFCNT($from_scalar), 1, 'data non-copy goes away, message refcnt--';

    lives_ok {
        undef $from_scalar;
    } 'undef $from_scalar lives ok';

    is SvREFCNT($scalar), 1, 'refcnt decremented when message went away';
}

{
    my $boring = ZeroMQ::Raw::Message->_new;
    ok !$boring->is_allocated, 'not allocated';
    lives_ok { $boring->init };

    ok $boring->is_allocated, 'allocated';
    throws_ok { $boring->init_size(42) }
        qr/A struct is already attached to this object/,
            'cannot init again';

    throws_ok { $boring->init }
        qr/A struct is already attached to this object/,
            'cannot init again';

    throws_ok { $boring->init_data("scalar") }
        qr/A struct is already attached to this object/,
            'cannot init again';
}

{
    my $utf8 = join '', (chr 12411, chr 12370); # ほげ
    ok utf8::is_utf8($utf8), 'got some utf8';
    my $msg;
    throws_ok {
        $msg = ZeroMQ::Raw::Message->new_from_scalar($utf8);
    } qr/wide character/i, 'wide character => death';
    ok !$msg;
}

{
    my $numb3r = 3;
    my $msg;
    throws_ok {
        $msg = ZeroMQ::Raw::Message->new_from_scalar($numb3r);
    } qr/SvPV/i, 'SvIV => nope.';
    ok !$msg
};

done_testing;
