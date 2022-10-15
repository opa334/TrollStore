#import <Foundation/Foundation.h>

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <sys/stat.h>

typedef enum {
	PWNIFY_STATE_NOT_PWNIFIED,
	PWNIFY_STATE_PWNIFIED_ARM64,
	PWNIFY_STATE_PWNIFIED_ARM64E
} pwnify_state;


extern void pwnify_enumerateArchs(NSString* binaryPath, void (^archEnumBlock)(struct fat_arch* arch, uint32_t archFileOffset, struct mach_header* machHeader, uint32_t sliceFileOffset, FILE* file, BOOL* stop));
extern void pwnify_setCPUSubtype(NSString* binaryPath, uint32_t subtype);
extern void pwnify(NSString* appStoreBinary, NSString* binaryToInject, BOOL preferArm64e, BOOL replaceBinaryToInject);
extern pwnify_state pwnifyGetBinaryState(NSString* binaryToCheck);