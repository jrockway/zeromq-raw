#include "EXTERN.h"
#include "perl.h"
#include "zmqxs.h"

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

/* magic for a SvPV whose buffer is owned by another SV */

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

int zmqxs_ref_mg_free(SV *sv, MAGIC* mg){
    /* printf("debug: decrementing refcnt on SV %p attached to %p\n",
              mg->mg_ptr, sv); */
    SvREFCNT_dec( (SV *) mg->mg_ptr);
}

void zmqxs_ref_sv(pTHX_ SV *sv, SV *ptr){
    /* printf("debug: attaching magical magic to %p (refs %p)\n", sv, ptr); */
    SvREFCNT_inc_simple_void_NN(ptr);
    sv_magicext(sv, NULL, PERL_MAGIC_ext, &ref_mg_vtbl, (void *) ptr, 0 );
}
