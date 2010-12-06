#ifndef ZMQXS_H
#define ZMQXS_H
#include <errno.h>
#include <xs_object_magic.h>
#include <zmq.h>

/* this can be zmq_errno() if errno does not work */
#define _ERRNO errno
#define SET_BANG zmqxs_set_bang(_ERRNO)

#define ZMQ_MSG_ALLOCATE(f)                  \
    msg = zmqxs_msg_start_allocate(self);    \
    zmqxs_msg_finish_allocate(self, f, msg); \

typedef void zmq_ctx_t;
typedef void zmq_sock_t;
typedef int zmq_sock_err; /* for the typemap */

/* tell zmq how to deref SVs */
void zmqxs_free_sv(void *, void *);

/* convenient macro for updating $! */
inline void zmqxs_set_bang(int);

/* utils to check that a struct is attached to our magic */
int zmqxs_has_object(SV *);
inline void zmqxs_ensure_unallocated(SV *);

/* allocation utils for messages */
inline zmq_msg_t *zmqxs_msg_start_allocate(SV *);
inline void zmqxs_msg_finish_allocate(SV *, int, zmq_msg_t *);

/* magic that lets one object refcnt++ another (and -- when freed)*/
int zmqxs_ref_mg_free(SV *, MAGIC *);
void zmqxs_ref_sv(pTHX_ SV *, SV *);

#endif
