#ifndef MACHO_LOAD_COMMAND_H
#define MACHO_LOAD_COMMAND_H

#include <mach-o/loader.h>
#include "MachO.h"
#include "FileStream.h"
#include "MachOByteOrder.h"
#include "CSBlob.h"

// Convert load command to load command name
char *load_command_to_string(int loadCommand);
void update_segment_command_64(MachO *macho, const char *segmentName, uint64_t vmaddr, uint64_t vmsize, uint64_t fileoff, uint64_t filesize);
void update_lc_code_signature(MachO *macho, uint64_t size);
int update_load_commands_for_coretrust_bypass(MachO *macho, CS_SuperBlob *superblob, uint64_t originalCodeSignatureSize, uint64_t originalMachOSize);

#endif // MACHO_LOAD_COMMAND_H