//
//  proc.h
//  fun15
//
//  Created by Lars Fröder on 11.06.22.
//

#ifndef proc_h
#define proc_h

#import <Foundation/Foundation.h>

#if defined(__cplusplus)
extern "C" {
#endif

struct k_posix_cred {                // (96 bytes)
    uid_t           cr_uid;        // off=0x0
    uid_t           cr_ruid;       // off=0x20
    uid_t           cr_svuid;      // off=0x40
    u_short         cr_ngroups;    // off=0x60
    u_short         __cr_padding;  // off=0x70
    gid_t           cr_groups[16]; // off=0x80
    gid_t           cr_rgid;       // off=0x280
    gid_t           cr_svgid;      // off=0x2a0
    uid_t           cr_gmuid;      // off=0x2c0
    int             cr_flags;      // off=0x2e0
};

struct k_label {                   // (64 bytes)
    int          l_flags;        // off=0x0
    int          l_perpolicy[7]; // off=0x40
};

struct k_ucred {  // (144 bytes)
    struct  {                     // (16 bytes)
    struct k_ucred *   le_next; // off=0x0
    struct k_ucred * * le_prev; // off=0x40
}                                            cr_link;  // off=0x0
    u_long                                   cr_ref;   // off=0x80
    struct k_posix_cred                        cr_posix; // off=0xc0
    struct k_label                             cr_label; // off=0x3c0
    struct au_session                        cr_audit; // off=0x400
};

extern void proc_set_posix_cred(uint64_t proc, struct k_posix_cred posix_cred);
extern struct k_posix_cred proc_get_posix_cred(uint64_t proc);

#if defined(__cplusplus)
}
#endif

#endif /* proc_h */
