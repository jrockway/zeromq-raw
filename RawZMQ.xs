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

inline void zmqxs_set_bang(int err){
    SV *errsv;
    errsv = get_sv("!", GV_ADD);
    sv_setsv(errsv, newSViv(err));
}

void zmqxs_free_sv(void *data, void *hint) {
     /* printf("debug: freeing data at %p, given SvPV with pointer at %p\n",
            data, SvPV_nolen((SV *) hint)); */
     SvREFCNT_dec((SV *) hint);
}

int zmqxs_has_object(SV *self){
    void *s = xs_object_magic_get_struct(aTHX_ SvRV(self));
    return (s != NULL);
}

inline void zmqxs_ensure_unallocated(SV *self) {
    if(zmqxs_has_object(self))
        croak("A struct is already attached to this object (SV %p)!", self);
}

inline zmq_msg_t *zmqxs_msg_start_allocate(SV *self) {
    zmq_msg_t *msg;
    zmqxs_ensure_unallocated(self);
    Newx(msg, 1, zmq_msg_t);
    if(msg == NULL)
       croak("Error allocating memory for zmq_msg_t structure!");
    return msg;
}

inline void zmqxs_msg_finish_allocate(SV *self, int status, zmq_msg_t *msg){
    if(status < 0){
        SET_BANG;
        Safefree(msg);
        if(_ERRNO == ENOMEM)
            croak("Insufficient space memory available for message.");
        croak("Unknown error initializing message!");
    }
    xs_object_magic_attach_struct(aTHX_ SvRV(self), msg);
}

#define ZMQ_MSG_ALLOCATE(f)                  \
    msg = zmqxs_msg_start_allocate(self);    \
    zmqxs_msg_finish_allocate(self, f, msg); \

/* magic for a SvPV whose buffer is owned by another SV */

int zmqxs_ref_mg_free(SV *sv, MAGIC* mg){
    /* printf("debug: decrementing refcnt on SV %p attached to %p\n",
              mg->mg_ptr, sv); */
    SvREFCNT_dec( (SV *) mg->mg_ptr);
}

STATIC MGVTBL ref_mg_vtbl = {
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    zmqxs_ref_mg_free, /* free */
#if MGf_COPY
    NULL, /* copy */
#endif /* MGf_COPY */
#if MGf_DUP
    NULL, /* dup */
#endif /* MGf_DUP */
#if MGf_LOCAL
    NULL, /* local */
#endif /* MGf_LOCAL */
};

void zmqxs_ref_sv(pTHX_ SV *sv, SV *ptr){
    /* printf("debug: attaching magical magic to %p (refs %p)\n", sv, ptr); */
    SvREFCNT_inc_simple_void_NN(ptr);
    sv_magicext(sv, NULL, PERL_MAGIC_ext, &ref_mg_vtbl, (void *) ptr, 0 );
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
        zmqxs_ensure_unallocated(self);
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

bool
zmq_has_valid_context(SV *self)
    CODE:
        RETVAL = zmqxs_has_object(self);
    OUTPUT:
        RETVAL

MODULE = ZeroMQ::Raw	PACKAGE = ZeroMQ::Raw::Message	PREFIX = zmq_msg_

void
zmq_msg_init(SV *self)
    PREINIT:
        zmq_msg_t *msg;
    CODE:
        ZMQ_MSG_ALLOCATE(zmq_msg_init(msg));

void
zmq_msg_init_size(SV *self, size_t size)
    PREINIT:
        zmq_msg_t *msg;
    CODE:
        ZMQ_MSG_ALLOCATE(zmq_msg_init_size(msg, size));

void
zmq_msg_init_data(SV *self, SV *data)
    PREINIT:
        zmq_msg_t *msg;
        STRLEN len;
        char *buf;
    CODE:
        if(!SvPOK(data))
            croak("You must pass init_data an SvPV and 0x%p is not one!", data);
        if(SvUTF8(data))
            croak("Wide character in init_data, you must encode characters!");

        buf = SvPV(data, len);
        ZMQ_MSG_ALLOCATE(zmq_msg_init_data(msg, buf, len, &zmqxs_free_sv, data));
        SvREFCNT_inc_simple_void_NN(data);

int
zmq_msg_size(zmq_msg_t *msg)

int
zmq_msg_data_nocopy(SV *self, SV *sv)
    PREINIT:
        char *buf;
        size_t len;
        zmq_msg_t *msg;
    CODE:
        msg = xs_object_magic_get_struct(aTHX_ SvRV(self));
        if(!msg)
            croak("Invalid call to zmq_msg_data: no zmq_msg_t attached!");

        len = zmq_msg_size(msg);
        if(len > 0){
            buf = zmq_msg_data(msg);
            /* printf("debug: sharing buf at %p\n", buf); */
            sv_upgrade(sv, SVt_PV);
            SvPV_set(sv, buf);
            SvCUR_set(sv, len);
            SvLEN_set(sv, len);
            SvPOK_on(sv);
            SvREADONLY_on(sv);
            /* make buf stay alive as long as sv is alive */
            zmqxs_ref_sv(aTHX_ sv, self);
            RETVAL = len;
        }
    OUTPUT:
        RETVAL

SV *
zmq_msg_data(zmq_msg_t *msg)
    PREINIT:
        char *buf;
        size_t len;
    CODE:
        len = zmq_msg_size(msg);
        if(len < 1)
            XSRETURN_UNDEF;

        buf = zmq_msg_data(msg);
        RETVAL = newSVpv(buf, len);
    OUTPUT:
        RETVAL

void
zmq_msg_close(zmq_msg_t *msg)
    PREINIT:
        int status = 0;
    CODE:
        status = zmq_msg_close(msg);
        if(status < 0){
            SET_BANG;
            croak("Error closing message %p!", msg);
        }

bool
zmq_msg_is_allocated(SV *self)
    CODE:
        RETVAL = zmqxs_has_object(self);
    OUTPUT:
        RETVAL
