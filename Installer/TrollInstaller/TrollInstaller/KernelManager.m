//
//  KernelManager.m
//  NonceSet15
//
//  Created by Lars Fröder on 02.06.22.
//

#import "KernelManager.h"

@implementation KernelManager

+ (instancetype)sharedInstance
{
    static KernelManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[KernelManager alloc] init];
    });
    return sharedInstance;
}

- (void)loadOffsets
{
    struct StaticOffsets staticOffsets;
    // iPhone 13 Pro, 15.1.1
    staticOffsets.kernel_base = 0xFFFFFFF007004000;
    staticOffsets.sandbox_secret = 0xFFFFFFF009DF2140;
    staticOffsets.allproc = 0xFFFFFFF009D86AA0;
    staticOffsets.kauth_cred_table_anchor = 0xFFFFFFF009DE0988;
    staticOffsets.cs_debug = 0xFFFFFFF009D86990;
    
    self.static_offsets = staticOffsets;
    
    struct ProcOffsets proc;
    proc.task_offset = 0x10;
    proc.pid_offset = 0x68;
    proc.comm_offset = 0x2C8;
    proc.name_offset = 0x2D9;
    proc.ucred_offset = 0xD8;
    proc.textvp_offset = 0x2A8;
    proc.textoff_offset = 0x2B0;
    proc.csflags_offset = 0x300;
    proc.fd_offset = 0xE0;
    
    struct UCredOffsets ucred;
    ucred.posix_offset = 0x18;
    ucred.label_offset = 0x78;
    ucred.audit_offset = 0x80;
    
    struct TaskOffsets task;
    task.map_offset = 0x28;
    task.threads_offset = 0x58;
    task.itk_space_offset = 0x330;
    task.rop_pid_offset = 0x360;
    task.jop_pid_offset = 0x368;
    task.disable_user_jop_offset = 0x370;
    task.t_flags_offset = 0x41C;
    
    struct ThreadOffsets thread;
    thread.task_threads_offset = 0x400;
    thread.disable_user_jop_offset = 0x167;
    thread.rop_pid_offset = 0x168;
    thread.jop_pid_offset = 0x170;
    
    struct ItkSpaceOffsets itk_space;
    itk_space.is_table_offset = 0x20;
    
    struct IpcEntryOffsets ipc_entry;
    ipc_entry.size = 0x18;
    
    struct FileDescriptorOffsets fd;
    fd.ofiles_offset = 0x20; // proc + 256
    // numfiles: 0xC, proc + 244
    // fd_ofileflags: proc + 264
    
    struct FileProcOffsets fproc;
    fproc.glob_offset = 0x10;
    
    struct FileGlobOffsets fglob;
    fglob.data_offset = 0x38;
    
    struct VnodeOffsets vnode;
    vnode.un_offset.ubcinfo = 0x78;
    vnode.type_offset = 0x70;
    vnode.flag_offset = 0x54;
    
    struct UbcInfoOffsets ubc_info;
    ubc_info.csblobs_offset = 0x50;
    
    struct CsBlobOffsets csblob;
    csblob.team_id_offset = 0x80;
    csblob.platform_binary_offset = 0xB8;
    csblob.pmap_cs_entry_offset = 0xC0;
    
    struct VmMapOffsets vmmap;
    vmmap.header_offset = 0x10;
    vmmap.pmap_offset = 0x48;
    vmmap.flag_offset = 0x11C;
    
    struct VmHeaderOffsets vmheader;
    vmheader.links_offset = 0x0;
    vmheader.numentry_offset = 0x20;
    
    struct VmMapLinkOffsets vmlink;
    vmlink.prev_offset = 0x0;
    vmlink.next_offset = 0x8;
    
    struct VmMapEntryOffsets vmentry;
    vmentry.links_offset = 0x0;
    vmentry.flag_bits_offset = 0x48;
    
    
    // vm header:
    // links: 0x00
    // nentries: 0x20
    // ..
    
    struct CsDirEntryOffsets csdirentry;
    csdirentry.trust_level_offset = 0x9C;
    
    struct StructOffsets structOffsets;
    structOffsets.proc = proc;
    structOffsets.ucred = ucred;
    structOffsets.task = task;
    structOffsets.thread = thread;
    structOffsets.itk_space = itk_space;
    structOffsets.ipc_entry = ipc_entry;
    structOffsets.fd = fd;
    structOffsets.fproc = fproc;
    structOffsets.fglob = fglob;
    structOffsets.vnode = vnode;
    structOffsets.ubc_info = ubc_info;
    structOffsets.csblob = csblob;
    structOffsets.vmmap = vmmap;
    structOffsets.csdirentry = csdirentry;
    structOffsets.vmheader = vmheader;
    structOffsets.vmlink = vmlink;
    structOffsets.vmentry = vmentry;
    
    self.struct_offsets = structOffsets;
}

- (void)_loadSlidOffsets
{
    struct SlidOffsets slidOffsets;
    slidOffsets.sandbox_secret = _static_offsets.sandbox_secret + self.kernel_slide;
    slidOffsets.allproc = _static_offsets.allproc + self.kernel_slide;
    slidOffsets.kauth_cred_table_anchor = _static_offsets.kauth_cred_table_anchor + self.kernel_slide;
    slidOffsets.cs_debug = _static_offsets.cs_debug + self.kernel_slide;
    self.slid_offsets = slidOffsets;
}

- (void)loadSlidOffsetsWithKernelSlide:(uint64_t)kernel_slide
{
    self.kernel_base = self.static_offsets.kernel_base + kernel_slide;
    self.kernel_slide = kernel_slide;
    [self _loadSlidOffsets];
}

- (void)loadSlidOffsetsWithKernelBase:(uint64_t)kernel_base
{
    self.kernel_base = kernel_base;
    self.kernel_slide = kernel_base - self.static_offsets.kernel_base;
    [self _loadSlidOffsets];
}

- (uint64_t)read64BitValueAtAddress:(uint64_t)addr
{
    if(_kread_64_d)
    {
        return _kread_64_d(addr);
    }
    else
    {
        uint64_t outInt = 0;
        int suc = 0;
        
        if(_kread_64_id)
        {
            _kread_64_id(addr, &outInt);
        }
        else if(_kread_64_id_ret)
        {
            suc = _kread_64_id_ret(addr, &outInt);
        }
        else if(_kread64_block)
        {
            suc = _kread64_block(addr, &outInt);
        }
        else
        {
            uint8_t* b = (uint8_t*)&outInt;
            *(uint32_t *)b = [self read32BitValueAtAddress:addr];
            *(uint32_t *)(b + 4) = [self read32BitValueAtAddress:addr + 4];
        }
        
        if(suc != 0)
        {
            NSLog(@"ERROR reading kernel memory (%llX): %d", addr, suc);
        }
        
        return outInt;
    }
    
}

- (uint32_t)read32BitValueAtAddress:(uint64_t)addr
{
    if(_kread_32_d)
    {
        return _kread_32_d(addr);
    }
    else
    {
        uint32_t outInt = 0;
        int suc = 0;
        if(_kread_32_id)
        {
            _kread_32_id(addr, &outInt);
        }
        else if(_kread_32_id_ret)
        {
            suc = _kread_32_id_ret(addr, &outInt);
        }
        else if(_kread32_block)
        {
            suc = _kread32_block(addr, &outInt);
        }
        if(suc != 0)
        {
            NSLog(@"ERROR read kernel memory (%llX): %d", addr, suc);
        }
        return outInt;
    }
}

- (int)readBufferAtAddress:(uint64_t)addr intoBuffer:(void*)outBuf withLength:(size_t)len
{
    //printf("read at %llX - %lX\n", addr, len);
    //usleep(50);
    
    if(_kread_buf)
    {
        return _kread_buf(addr, outBuf, len);
    }
    else
    {
        uint64_t endAddr = addr + len;
        uint32_t outputOffset = 0;
        unsigned char* outputBytes = (unsigned char*)outBuf;
        
        for(uint64_t curAddr = addr; curAddr < endAddr; curAddr += 4)
        {
            //printf("read %llX\n", curAddr);
            //usleep(1000);
            uint32_t k = [self read32BitValueAtAddress:curAddr];

            unsigned char* kb = (unsigned char*)&k;
            for(int i = 0; i < 4; i++)
            {
                if(outputOffset == len) break;
                outputBytes[outputOffset] = kb[i];
                outputOffset++;
            }
            if(outputOffset == len) break;
        }
        
        return 0;
    }
}

- (int)copyStringAtAddress:(uint64_t)addr intoBuffer:(void*)outBuf withBufferSize:(size_t)bufSize
{
    bzero(outBuf, bufSize);
    char* outBufStr = (char*)outBuf;
    
    uint64_t maxEndAddr = addr + bufSize;
    int ci = 0;
    
    for(uint64_t curAddr = addr; curAddr < maxEndAddr; curAddr += 4)
    {
        uint32_t k = [self read32BitValueAtAddress:curAddr];
        char* kb = (char*)&k;
        for(int i = 0; i < 4; i++)
        {
            char c = kb[i];
            if(c == '\0') return 0;
            outBufStr[ci] = c;
            ci++;
        }
    }
    return 0;
}

void DumpHex(const void* data, size_t size) {
    char ascii[17];
    size_t i, j;
    ascii[16] = '\0';
    for (i = 0; i < size; ++i) {
        if(i % 16 == 0)
        {
            printf("0x%zX | ", i);
        }
        printf("%02X ", ((unsigned char*)data)[i]);
        if (((unsigned char*)data)[i] >= ' ' && ((unsigned char*)data)[i] <= '~') {
            ascii[i % 16] = ((unsigned char*)data)[i];
        } else {
            ascii[i % 16] = '.';
        }
        if ((i+1) % 8 == 0 || i+1 == size) {
            printf(" ");
            if ((i+1) % 16 == 0) {
                printf("|  %s \n", ascii);
            } else if (i+1 == size) {
                ascii[(i+1) % 16] = '\0';
                if ((i+1) % 16 <= 8) {
                    printf(" ");
                }
                for (j = (i+1) % 16; j < 16; ++j) {
                    printf("   ");
                }
                printf("|  %s \n", ascii);
            }
        }
    }
}

- (int)dumpHexAtAddress:(uint64_t)addr withLength:(size_t)len
{
    void* buffer = malloc(len);
    int ret = [self readBufferAtAddress:addr intoBuffer:buffer withLength:len];
    if(ret == 0)
    {
        DumpHex(buffer, len);
    }
    free(buffer);
    return ret;
}

- (int)write64BitValue:(uint64_t)value toAddress:(uint64_t)addr
{
    if(_kwrite_64)
    {
        _kwrite_64(addr, value);
    }
    else if(_kwrite_64_ret)
    {
        return _kwrite_64_ret(addr, value);
    }
    else if(_kwrite64_block)
    {
        return _kwrite64_block(addr, value);
    }
    else
    {
        int r1 = [self write32BitValue:(uint32_t)value toAddress:addr];
        int r2 = [self write32BitValue:(uint32_t)(value >> 32) toAddress:addr + 4];
        return r1 || r2;
    }
    return 0;
}

- (int)write32BitValue:(uint32_t)value toAddress:(uint64_t)addr
{
    if(_kwrite_32)
    {
        _kwrite_32(addr, value);
    }
    else if(_kwrite_32_ret)
    {
        return _kwrite_32_ret(addr, value);
    }
    else if(_kwrite32_block)
    {
        return _kwrite32_block(addr, value);
    }
    return 0;
}

- (int)writeBuffer:(void*)inBuf withLength:(size_t)len toAddress:(uint64_t)addr
{
    //printf("write to %llX - %lX\n", addr, len);
    //usleep(50);

    if(_kwrite_buf)
    {
        return _kwrite_buf(addr, inBuf, len);
    }
    else
    {
        uint64_t endAddr = addr + len;
        uint32_t inputOffset = 0;
        unsigned char* inputBytes = (unsigned char*)inBuf;
        
        for(uint64_t curAddr = addr; curAddr < endAddr; curAddr += 4)
        {
            uint32_t toWrite = 0;
            int bc = 4;
            
            uint64_t remainingBytes = endAddr - curAddr;
            if(remainingBytes < 4)
            {
                toWrite = [self read32BitValueAtAddress:curAddr];
                bc = (int)remainingBytes;
            }
            
            unsigned char* wb = (unsigned char*)&toWrite;
            for(int i = 0; i < bc; i++)
            {
                wb[i] = inputBytes[inputOffset];
                inputOffset++;
            }
            
            //printf("write %X to %llX\n", toWrite, curAddr);
            //usleep(1000);

            [self write32BitValue:toWrite toAddress:curAddr];
        }

        return 0;
    }
    return 0;
}

- (void)finishAndCleanupIfNeeded
{
    if(_kcleanup)
    {
        _kcleanup();
    }
}

- (void)dealloc
{
    [self finishAndCleanupIfNeeded];
}

@end
