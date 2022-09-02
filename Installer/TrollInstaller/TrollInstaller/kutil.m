//
//  proc.m
//  fun15
//
//  Created by Lars Fröder on 11.06.22.
//

#import "kutil.h"

#import <Foundation/Foundation.h>

#import "KernelManager.h"
#import "exploit/xpaci.h"

struct k_posix_cred proc_get_posix_cred(uint64_t proc)
{
    struct k_posix_cred pcred = {0};
    KernelManager* km = [KernelManager sharedInstance];
    uint64_t ucred = xpaci([km read64BitValueAtAddress:proc + km.struct_offsets.proc.ucred_offset]);
    uint64_t posix_cred_kptr = ucred + km.struct_offsets.ucred.posix_offset;
    [km readBufferAtAddress:posix_cred_kptr intoBuffer:&pcred withLength:sizeof(struct k_posix_cred)];
    return pcred;
}

void proc_set_posix_cred(uint64_t proc, struct k_posix_cred posix_cred)
{
    KernelManager* km = [KernelManager sharedInstance];
    uint64_t ucred = xpaci([km read64BitValueAtAddress:proc + km.struct_offsets.proc.ucred_offset]);
    uint64_t posix_cred_kptr = ucred + km.struct_offsets.ucred.posix_offset;
    [km writeBuffer:&posix_cred withLength:sizeof(struct k_posix_cred) toAddress:posix_cred_kptr];
}
