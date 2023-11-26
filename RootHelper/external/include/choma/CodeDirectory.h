#ifndef CODE_DIRECTORY_H
#define CODE_DIRECTORY_H

#include <stdint.h>
#include <math.h>
#include <CommonCrypto/CommonDigest.h>

#include "MachO.h"
#include "CSBlob.h"
#include "FAT.h"
#include "MachOByteOrder.h"
#include "MachOLoadCommand.h"
#include "MemoryStream.h"


// Code directory blob header
typedef struct __CodeDirectory {
	uint32_t magic;
	uint32_t length;
	uint32_t version;
	uint32_t flags;
	uint32_t hashOffset;
	uint32_t identOffset;
	uint32_t nSpecialSlots;
	uint32_t nCodeSlots;
	uint32_t codeLimit;
	uint8_t hashSize;
	uint8_t hashType;
	uint8_t spare1;
	uint8_t	pageSize;
	uint32_t spare2;
	uint32_t scatterOffset;
	uint32_t teamOffset;
} CS_CodeDirectory;

enum CS_HashType {
	CS_HASHTYPE_SHA160_160 = 1,
	CS_HASHTYPE_SHA256_256 = 2,
	CS_HASHTYPE_SHA256_160 = 3,
	CS_HASHTYPE_SHA384_384 = 4,
};

char *csd_code_directory_copy_identity(CS_DecodedBlob *codeDirBlob, uint32_t *offsetOut);
char *csd_code_directory_copy_team_id(CS_DecodedBlob *codeDirBlob, uint32_t *offsetOut);
int csd_code_directory_set_team_id(CS_DecodedBlob *codeDirBlob, char *newTeamID);
uint32_t csd_code_directory_get_flags(CS_DecodedBlob *codeDirBlob);
void csd_code_directory_set_flags(CS_DecodedBlob *codeDirBlob, uint32_t flags);
uint8_t csd_code_directory_get_hash_type(CS_DecodedBlob *codeDirBlob);
void csd_code_directory_set_hash_type(CS_DecodedBlob *codeDirBlob, uint8_t hashType);
int csd_code_directory_print_content(CS_DecodedBlob *codeDirBlob, MachO *macho, bool printSlots, bool verifySlots);
void csd_code_directory_update(CS_DecodedBlob *codeDirBlob, MachO *macho);

#endif // CODE_DIRECTORY_H