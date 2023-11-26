#ifndef MACHO_SLICE_H
#define MACHO_SLICE_H

#include <stdbool.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include "MemoryStream.h"
#include "FAT.h"

typedef struct MachOSegment
{
    struct segment_command_64 command;
    struct section_64 sections[];
} __attribute__((__packed__)) MachOSegment;

typedef struct FilesetMachO {
    char *entry_id;
    uint64_t vmaddr;
    uint64_t fileoff;
	FAT *underlyingMachO;
} FilesetMachO;

typedef struct MachO {
    MemoryStream *stream;
    bool isSupported;
    struct mach_header_64 machHeader;
    struct fat_arch_64 archDescriptor;

    uint32_t filesetCount;
    FilesetMachO *filesetMachos;

    uint32_t segmentCount;
    MachOSegment **segments;
} MachO;

// Read data from a MachO at a specified offset
int macho_read_at_offset(MachO *macho, uint64_t offset, size_t size, void *outBuf);

// Write data from a MachO at a specified offset, auto expands, only works if opened via macho_init_for_writing
int macho_write_at_offset(MachO *macho, uint64_t offset, size_t size, void *inBuf);

MemoryStream *macho_get_stream(MachO *macho);
uint32_t macho_get_filetype(MachO *macho);

// Perform translation between file offsets and virtual addresses
int macho_translate_fileoff_to_vmaddr(MachO *macho, uint64_t fileoff, uint64_t *vmaddrOut, MachOSegment **segmentOut);
int macho_translate_vmaddr_to_fileoff(MachO *macho, uint64_t vmaddr, uint64_t *fileoffOut, MachOSegment **segmentOut);

// Read data from a MachO at a specified virtual address
int macho_read_at_vmaddr(MachO *macho, uint64_t vmaddr, size_t size, void *outBuf);

int macho_enumerate_load_commands(MachO *macho, void (^enumeratorBlock)(struct load_command loadCommand, uint64_t offset, void *cmd, bool *stop));

// Initialise a MachO object from a MemoryStream and it's corresponding FAT arch descriptor
MachO *macho_init(MemoryStream *stream, struct fat_arch_64 archDescriptor);

// Initialize a single slice macho for writing to it
MachO *macho_init_for_writing(const char *filePath);

void macho_free(MachO *macho);

#endif // MACHO_SLICE_H