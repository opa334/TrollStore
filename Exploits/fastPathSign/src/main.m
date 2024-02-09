#include "codesign.h"
#include "coretrust_bug.h"
#include "FAT.h"
#include "MachO.h"
#include "FileStream.h"
#include "Host.h"
#include <copyfile.h>

#define CPU_SUBTYPE_ARM64E_ABI_V2 0x80000000

char *extract_preferred_slice(const char *fatPath)
{
    FAT *fat = fat_init_from_path(fatPath);
    if (!fat) return NULL;
    MachO *macho = fat_find_preferred_slice(fat);

#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    if (!macho) {
        // Check for arm64v8 first
        macho = fat_find_slice(fat, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_V8);
        if (!macho) {
            // If that fails, check for regular arm64
            macho = fat_find_slice(fat, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL);
            if (!macho) {
                // If that fails, check for arm64e with ABI v2
                macho = fat_find_slice(fat, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64E | CPU_SUBTYPE_ARM64E_ABI_V2);
                if (!macho) {
                    // If that fails, check for arm64e
                    macho = fat_find_slice(fat, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64E);
                    if (!macho) {
                        fat_free(fat);
                        return NULL;
                    }
                }
            }
        }
    }
#else
    if (!macho) {
        fat_free(fat);
        return NULL;
    }
#endif // TARGET_OS_MAC && !TARGET_OS_IPHONE
    
    char *temp = strdup("/tmp/XXXXXX");
    int fd = mkstemp(temp);

    MemoryStream *outStream = file_stream_init_from_path(temp, 0, 0, FILE_STREAM_FLAG_WRITABLE | FILE_STREAM_FLAG_AUTO_EXPAND);
    MemoryStream *machoStream = macho_get_stream(macho);
    memory_stream_copy_data(machoStream, 0, outStream, 0, memory_stream_get_size(machoStream));

    fat_free(fat);
    memory_stream_free(outStream);
    close(fd);
    return temp;
}


int main(int argc, char *argv[]) {
	if (argc < 2) return -1;

    char *input = argv[argc-1];

    NSDictionary *customEntitlements = nil;
    if (argc == 4) {
        if (!strcmp(argv[1], "--entitlements")) {
            NSString *entitlementsPath = [NSString stringWithUTF8String:argv[2]];
            customEntitlements = [NSDictionary dictionaryWithContentsOfFile:entitlementsPath];
        }
    }

    int r = codesign_sign_adhoc(input, true, customEntitlements);
	if (r != 0) {
		printf("Failed adhoc signing (%d) Continuing anyways...\n", r);
	}
    else {
        printf("AdHoc signed file!\n");
    }

	char *machoPath = extract_preferred_slice(input);
    if (!machoPath) {
        printf("Failed extracting best slice\n");
        return -1;
    }
	printf("Extracted best slice to %s\n", machoPath);

    printf("Applying CoreTrust bypass...\n");

    r = apply_coretrust_bypass(machoPath);

	if (r != 0) {
		printf("Failed applying CoreTrust bypass\n");
		return r;
	}

    if (copyfile(machoPath, input, 0, COPYFILE_ALL | COPYFILE_MOVE | COPYFILE_UNLINK) == 0) {
        chmod(input, 0755);
        printf("Applied CoreTrust Bypass!\n");
    }
    else {
        perror("copyfile");
		return -1;
    }

	free(machoPath);
	return 0;
}