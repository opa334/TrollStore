//
//  KernelManager.h
//  NonceSet15
//
//  Created by Lars Fröder on 02.06.22.
//

#import <Foundation/Foundation.h>

struct StaticOffsets
{
    uint64_t kernel_base;
    uint64_t kauth_cred_table_anchor;
    uint64_t allproc;
    uint64_t sandbox_secret;
    uint64_t cs_debug;
};

struct SlidOffsets
{
    uint64_t kauth_cred_table_anchor;
    uint64_t allproc;
    uint64_t sandbox_secret;
    uint64_t cs_debug;
};

struct UCredOffsets
{
    uint64_t posix_offset;
    uint64_t label_offset;
    uint64_t audit_offset;
};

struct TaskOffsets
{
    uint64_t itk_space_offset;
    uint64_t t_flags_offset;
    uint64_t rop_pid_offset;
    uint64_t jop_pid_offset;
    uint64_t disable_user_jop_offset;
    uint64_t threads_offset;
    uint64_t map_offset;
};

struct ThreadOffsets
{
    uint64_t task_threads_offset;
    uint64_t disable_user_jop_offset;
    uint64_t rop_pid_offset;
    uint64_t jop_pid_offset;
};

struct ProcOffsets
{
    uint64_t task_offset;
    uint64_t pid_offset;
    uint64_t comm_offset;
    uint64_t name_offset;
    uint64_t ucred_offset;
    uint64_t textvp_offset;
    uint64_t textoff_offset;
    uint64_t csflags_offset;
    uint64_t fd_offset;
};

struct FileDescriptorOffsets
{
    uint64_t ofiles_offset;
};

struct FileProcOffsets
{
    uint64_t glob_offset;
};

struct FileGlobOffsets
{
    uint64_t data_offset;
};

struct ItkSpaceOffsets
{
    uint64_t is_table_offset;
};

struct IpcEntryOffsets
{
    uint32_t size;
};

struct CsBlobOffsets
{
    uint64_t team_id_offset;
    uint64_t platform_binary_offset;
    uint64_t pmap_cs_entry_offset;
};

struct UbcInfoOffsets
{
    uint64_t csblobs_offset;
};

struct VnodeOffsets
{
    union un {
        uint64_t mountedhere;
        uint64_t socket;
        uint64_t specinfo;
        uint64_t fifoinfo;
        uint64_t ubcinfo;
    } un_offset;
    uint64_t type_offset;
    uint64_t flag_offset;
};

struct VmMapOffsets
{
    uint64_t header_offset;
    uint64_t pmap_offset;
    uint64_t flag_offset;
};

struct VmHeaderOffsets
{
    uint64_t links_offset;
    uint64_t numentry_offset;
};

struct VmMapLinkOffsets
{
    uint64_t prev_offset;
    uint64_t next_offset;
};

struct CsDirEntryOffsets
{
    uint64_t trust_level_offset;
};

struct VmMapEntryOffsets
{
    uint64_t links_offset;
    uint64_t flag_bits_offset;
};

/*struct PmapOffsets
{
    
}*/

#define un_mountedhere un.mountedhere
#define un_socket un.socket
#define un_specinfo un.specinfo
#define un_fifoinfo un.fifoinfo
#define un_ubcinfo un.ubcinfo

struct StructOffsets
{
    struct ProcOffsets proc;
    struct UCredOffsets ucred;
    struct ItkSpaceOffsets itk_space;
    struct TaskOffsets task;
    struct ThreadOffsets thread;
    struct IpcEntryOffsets ipc_entry;
    struct FileDescriptorOffsets fd;
    struct FileProcOffsets fproc;
    struct FileGlobOffsets fglob;
    struct VnodeOffsets vnode;
    struct UbcInfoOffsets ubc_info;
    struct CsBlobOffsets csblob;
    struct VmMapOffsets vmmap;
    struct CsDirEntryOffsets csdirentry;
    struct VmHeaderOffsets vmheader;
    struct VmMapLinkOffsets vmlink;
    struct VmMapEntryOffsets vmentry;
};

NS_ASSUME_NONNULL_BEGIN

@interface KernelManager : NSObject
{
}

@property (nonatomic) uint32_t (*kread_32_d)(uint64_t addr);
@property (nonatomic) uint64_t (*kread_64_d)(uint64_t addr);
@property (nonatomic) void (*kread_32_id)(uint64_t addr, uint32_t* outPtr);
@property (nonatomic) void (*kread_64_id)(uint64_t addr, uint64_t* outPtr);
@property (nonatomic) int (*kread_32_id_ret)(uint64_t addr, uint32_t* outPtr);
@property (nonatomic) int (*kread_64_id_ret)(uint64_t addr, uint64_t* outPtr);
@property (nonatomic, copy) int (^kread32_block)(uint64_t addr, uint32_t* outPtr);
@property (nonatomic, copy) int (^kread64_block)(uint64_t addr, uint64_t* outPtr);

@property (nonatomic) void (*kwrite_32)(uint64_t addr, uint32_t value);
@property (nonatomic) void (*kwrite_64)(uint64_t addr, uint64_t value);
@property (nonatomic) int (*kwrite_32_ret)(uint64_t addr, uint32_t value);
@property (nonatomic) int (*kwrite_64_ret)(uint64_t addr, uint64_t value);
@property (nonatomic, copy) int (^kwrite32_block)(uint64_t addr, uint32_t value);
@property (nonatomic, copy) int (^kwrite64_block)(uint64_t addr, uint64_t value);

@property (nonatomic) int (*kread_buf)(uint64_t addr, void* outBuf, size_t len);
@property (nonatomic) int (*kwrite_buf)(uint64_t addr, void* inBuf, size_t len);

@property (nonatomic) void (*kcleanup)(void);

@property (nonatomic) uint64_t kernel_slide;
@property (nonatomic) uint64_t kernel_base;

@property (nonatomic) struct SlidOffsets slid_offsets;
@property (nonatomic) struct StaticOffsets static_offsets;
@property (nonatomic) struct StructOffsets struct_offsets;

- (void)loadOffsets;
- (void)_loadSlidOffsets;
- (void)loadSlidOffsetsWithKernelSlide:(uint64_t)kernel_slide;
- (void)loadSlidOffsetsWithKernelBase:(uint64_t)kernel_base;

+ (instancetype)sharedInstance;

- (uint64_t)read64BitValueAtAddress:(uint64_t)addr;
- (uint32_t)read32BitValueAtAddress:(uint64_t)addr;
- (int)readBufferAtAddress:(uint64_t)addr intoBuffer:(void*)outBuf withLength:(size_t)len;
- (int)copyStringAtAddress:(uint64_t)addr intoBuffer:(void*)outBuf withBufferSize:(size_t)bufSize;
- (int)dumpHexAtAddress:(uint64_t)addr withLength:(size_t)len;

- (int)write64BitValue:(uint64_t)value toAddress:(uint64_t)addr;
- (int)write32BitValue:(uint32_t)value toAddress:(uint64_t)addr;
- (int)writeBuffer:(void*)inBuf withLength:(size_t)len toAddress:(uint64_t)addr;

- (void)finishAndCleanupIfNeeded;
@end

NS_ASSUME_NONNULL_END
