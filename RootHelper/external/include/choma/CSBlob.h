#ifndef CS_BLOB_H
#define CS_BLOB_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#include "FAT.h"
#include "MachO.h"
#include "MemoryStream.h"

// Blob index
typedef struct __BlobIndex {
    uint32_t type;
    uint32_t offset;
} CS_BlobIndex;

// CMS superblob
typedef struct __SuperBlob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
    CS_BlobIndex index[];
} CS_SuperBlob;

typedef struct __GenericBlob {
    uint32_t magic;					/* magic number */
    uint32_t length;				/* total length of blob */
    char data[];
} CS_GenericBlob;

// CMS blob magic types
enum {
    CSMAGIC_REQUIREMENT = 0xfade0c00,
    CSMAGIC_REQUIREMENTS = 0xfade0c01,
    CSMAGIC_CODEDIRECTORY = 0xfade0c02,
    CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0,
    CSMAGIC_EMBEDDED_SIGNATURE_OLD = 0xfade0b02,
    CSMAGIC_EMBEDDED_ENTITLEMENTS = 0xfade7171,
    CSMAGIC_EMBEDDED_DER_ENTITLEMENTS = 0xfade7172,
    CSMAGIC_DETACHED_SIGNATURE = 0xfade0cc1,
    CSMAGIC_BLOBWRAPPER = 0xfade0b01,
    CSMAGIC_EMBEDDED_LAUNCH_CONSTRAINT = 0xfade8181,
} CS_BlobMagic;

enum {
    CSSLOT_CODEDIRECTORY = 0,
    CSSLOT_INFOSLOT = 1,
    CSSLOT_REQUIREMENTS = 2,
    CSSLOT_RESOURCEDIR = 3,
    CSSLOT_APPLICATION = 4,
    CSSLOT_ENTITLEMENTS = 5,
    CSSLOT_DER_ENTITLEMENTS = 7,
    CSSLOT_LAUNCH_CONSTRAINT_SELF = 8,
    CSSLOT_LAUNCH_CONSTRAINT_PARENT = 9,
    CSSLOT_LAUNCH_CONSTRAINT_RESPONSIBLE = 10,
    CSSLOT_LIBRARY_CONSTRAINT = 11,

    CSSLOT_ALTERNATE_CODEDIRECTORIES = 0x1000, /* first alternate CodeDirectory, if any */
    CSSLOT_ALTERNATE_CODEDIRECTORY_MAX = 5,         /* max number of alternate CD slots */
    CSSLOT_ALTERNATE_CODEDIRECTORY_LIMIT = CSSLOT_ALTERNATE_CODEDIRECTORIES + CSSLOT_ALTERNATE_CODEDIRECTORY_MAX, /* one past the last */

    CSSLOT_SIGNATURESLOT = 0x10000,
    CSSLOT_IDENTIFICATIONSLOT = 0x10001,
    CSSLOT_TICKETSLOT = 0x10002,
} CS_SlotType;

typedef struct s_CS_DecodedBlob {
    struct s_CS_DecodedBlob *next;
    uint32_t type;
    MemoryStream *stream;
} CS_DecodedBlob;

typedef struct s_CS_DecodedSuperBlob {
    uint32_t magic;
    struct s_CS_DecodedBlob *firstBlob;
} CS_DecodedSuperBlob;

// Convert blob magic to readable blob type string
const char *cs_blob_magic_to_string(uint32_t magic);
const char *cs_slot_type_to_string(uint32_t slotType);

// Extract Code Signature to file
int macho_extract_cs_to_file(MachO *macho, CS_SuperBlob *superblob);

int macho_find_code_signature_bounds(MachO *macho, uint32_t *offsetOut, uint32_t *sizeOut);

CS_SuperBlob *macho_read_code_signature(MachO *macho);

int macho_replace_code_signature(MachO *macho, CS_SuperBlob *superblob);

int update_load_commands(MachO *macho, CS_SuperBlob *superblob, uint64_t originalSize);

CS_DecodedBlob *csd_blob_init(uint32_t type, CS_GenericBlob *blobData);
int csd_blob_read(CS_DecodedBlob *blob, uint64_t offset, size_t size, void *outBuf);
int csd_blob_write(CS_DecodedBlob *blob, uint64_t offset, size_t size, const void *inBuf);
int csd_blob_insert(CS_DecodedBlob *blob, uint64_t offset, size_t size, const void *inBuf);
int csd_blob_delete(CS_DecodedBlob *blob, uint64_t offset, size_t size);
int csd_blob_read_string(CS_DecodedBlob *blob, uint64_t offset, char **outString);
int csd_blob_write_string(CS_DecodedBlob *blob, uint64_t offset, const char *string);
int csd_blob_get_size(CS_DecodedBlob *blob);
uint32_t csd_blob_get_type(CS_DecodedBlob *blob);
void csd_blob_set_type(CS_DecodedBlob *blob, uint32_t type);
void csd_blob_free(CS_DecodedBlob *blob);

CS_DecodedSuperBlob *csd_superblob_decode(CS_SuperBlob *superblob);
CS_SuperBlob *csd_superblob_encode(CS_DecodedSuperBlob *decodedSuperblob);
CS_DecodedBlob *csd_superblob_find_blob(CS_DecodedSuperBlob *superblob, uint32_t type, uint32_t *indexOut);
int csd_superblob_insert_blob_after_blob(CS_DecodedSuperBlob *superblob, CS_DecodedBlob *blobToInsert, CS_DecodedBlob *afterBlob);
int csd_superblob_insert_blob_at_index(CS_DecodedSuperBlob *superblob, CS_DecodedBlob *blobToInsert, uint32_t atIndex);
int csd_superblob_append_blob(CS_DecodedSuperBlob *superblob, CS_DecodedBlob *blobToAppend);
int csd_superblob_remove_blob(CS_DecodedSuperBlob *superblob, CS_DecodedBlob *blobToRemove); // <- Important: When calling this, caller is responsible for freeing blobToRemove
int csd_superblob_remove_blob_at_index(CS_DecodedSuperBlob *superblob, uint32_t atIndex);
int csd_superblob_print_content(CS_DecodedSuperBlob *decodedSuperblob, MachO *macho, bool printAllSlots, bool verifySlots);
void csd_superblob_free(CS_DecodedSuperBlob *decodedSuperblob);


#endif // CS_BLOB_H