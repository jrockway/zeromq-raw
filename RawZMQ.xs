#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <errno.h>
#include "ppport.h"
#include <xs_object_magic.h>
#include <zmq.h>

/* this can be zmq_errno() if errno does not work */
#define _ERRNO errno
#define SET_BANG zmqxs_set_bang(_ERRNO)

typedef void zmq_ctx_t;

void zmqxs_set_bang(int err){
    SV *errsv;
    errsv = get_sv("!", GV_ADD);
    sv_setsv(errsv, newSViv(err));
}

MODULE = ZeroMQ::Raw	PACKAGE = ZeroMQ::Raw   PREFIX = zmq_
PROTOTYPES: DISABLE

void
zmq_version()
    PREINIT:
        int major, minor, patch = 0;
    PPCODE:
        zmq_version(&major, &minor, &patch);
        EXTEND(SP, 3);
        PUSHs(sv_2mortal(newSViv(major)));
        PUSHs(sv_2mortal(newSViv(minor)));
        PUSHs(sv_2mortal(newSViv(patch)));

MODULE = ZeroMQ::Raw	PACKAGE = ZeroMQ::Raw::Context	PREFIX = zmq_

void
zmq_init(SV *self, int threads)
    PREINIT:
        zmq_ctx_t *ctx;

    CODE:
        ctx = zmq_init(threads);
        if(ctx == NULL){
            SET_BANG;
            if(_ERRNO == EINVAL)
                croak("Invalid number of threads (%d) passed to zmq_init!", threads);

            croak("Unknown error allocating ZMQ context!");
        }
        xs_object_magic_attach_struct(aTHX_ SvRV(self), ctx);

void
zmq_term(zmq_ctx_t *ctx);
    PREINIT:
        int status = 0;
    CODE:
        status = zmq_term(ctx);
        if(status < 0){
            SET_BANG;
            if(_ERRNO == EFAULT)
                croak("Invalid context (%p) passed to zmq_term!", ctx);

            croak("Unknown error terminating ZMQ context!");
        }

SV *
zmq_has_valid_context(SV *self)
    PPCODE:
        void *s = xs_object_magic_get_struct(aTHX_ SvRV(self));
        if(s == NULL)
            XSRETURN_UNDEF;
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSViv(1)));
