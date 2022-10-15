//
//  main.m
//  pwnify-universal
//
//  Created by Lars Fröder on 08.10.22.
//

#import <Foundation/Foundation.h>
#import <libPwnify.h>

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <sys/stat.h>

void printArchs(NSString* binaryPath)
{
	__block int i = 0;
	pwnify_enumerateArchs(binaryPath, ^(struct fat_arch* arch, uint32_t archFileOffset, struct mach_header* machHeader, uint32_t sliceFileOffset, FILE* file, BOOL* stop) {
		if(arch)
		{
			printf("%d. fatArch type: 0x%X, subtype: 0x%X, align:0x%X, size:0x%X, offset:0x%X\n| ", i, OSSwapBigToHostInt32(arch->cputype), OSSwapBigToHostInt32(arch->cpusubtype), OSSwapBigToHostInt32(arch->align), OSSwapBigToHostInt32(arch->size), OSSwapBigToHostInt32(arch->offset));
		}
		printf("machHeader type: 0x%X, subtype: 0x%X\n", OSSwapLittleToHostInt32(machHeader->cputype), OSSwapLittleToHostInt32(machHeader->cpusubtype));

		i++;
	});
}

void printUsageAndExit(void)
{
	printf("Usage:\n\nPrint architectures of a binary:\npwnify print <path/to/binary>\n\nInject target slice into victim binary:\npwnify pwn(64e) <path/to/victim/binary> <path/to/target/binary>\n\nModify cpusubtype of a non FAT binary:\npwnify set-cpusubtype <path/to/binary> <cpusubtype>\n");
	exit(0);
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		if(argc < 3)
		{
			printUsageAndExit();
		}
		
		NSString* operation = [NSString stringWithUTF8String:argv[1]];
		
		if([operation isEqualToString:@"print"])
		{
			NSString* binaryToPrint = [NSString stringWithUTF8String:argv[2]];
			printArchs(binaryToPrint);
		}
		else if([operation isEqualToString:@"pwn"])
		{
			if(argc < 4) printUsageAndExit();
			NSString* victimBinary = [NSString stringWithUTF8String:argv[2]];
			NSString* targetBinary = [NSString stringWithUTF8String:argv[3]];
			pwnify(victimBinary, targetBinary, NO, NO);
		}
		else if([operation isEqualToString:@"pwn64e"])
		{
			if(argc < 4) printUsageAndExit();
			NSString* victimBinary = [NSString stringWithUTF8String:argv[2]];
			NSString* targetBinary = [NSString stringWithUTF8String:argv[3]];
			pwnify(victimBinary, targetBinary, YES, NO);
		}
		else if([operation isEqualToString:@"set-cpusubtype"])
		{
			if(argc < 4) printUsageAndExit();
			NSString* binaryToModify = [NSString stringWithUTF8String:argv[2]];
			NSString* subtypeToSet = [NSString stringWithUTF8String:argv[3]];
			
			NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
			f.numberStyle = NSNumberFormatterDecimalStyle;
			NSNumber* subtypeToSetNum = [f numberFromString:subtypeToSet];

			pwnify_setCPUSubtype(binaryToModify, [subtypeToSetNum unsignedIntValue]);
		}
		else
		{
			printUsageAndExit();
		}
	}
	return 0;
}
