#ifndef MACHO_H
#define MACHO_H

#include <stdio.h>
#include <libkern/OSByteOrder.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <sys/stat.h>

#include "MemoryStream.h"
typedef struct MachO MachO;

// A FAT structure can either represent a FAT file with multiple slices, in which the slices will be loaded into the slices attribute
// Or a single slice MachO, in which case it serves as a compatibility layer and the single slice will also be loaded into the slices attribute
typedef struct FAT
{
    MemoryStream *stream;
    MachO **slices;
    uint32_t slicesCount;
    int fileDescriptor;
} FAT;

int fat_read_at_offset(FAT *fat, uint64_t offset, size_t size, void *outBuf);

MemoryStream *fat_get_stream(FAT *fat);

// Initialise a FAT structure from a memory stream
FAT *fat_init_from_memory_stream(MemoryStream *stream);

// Initialise a FAT structure using the path to the file
FAT *fat_init_from_path(const char *filePath);

// Find macho with cputype and cpusubtype in FAT, returns NULL if not found
MachO *fat_find_slice(FAT *fat, cpu_type_t cputype, cpu_subtype_t cpusubtype);

// Create a FAT structure from an array of MachO structures
FAT *fat_create_for_macho_array(char *firstInputPath, MachO **machoArray, int machoArrayCount);

// Add a MachO to the FAT structure
int fat_add_macho(FAT *fat, MachO *macho);

// Free all elements of the FAT structure
void fat_free(FAT *fat);

#endif // MACHO_H