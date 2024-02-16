#import "TSUtil.h"

#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

static EXPLOIT_TYPE gPlatformVulnerabilities;

void* _CTServerConnectionCreate(CFAllocatorRef, void *, void *);
int64_t _CTServerConnectionSetCellularUsagePolicy(CFTypeRef* ct, NSString* identifier, NSDictionary* policies);

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

void chineseWifiFixup(void)
{
	_CTServerConnectionSetCellularUsagePolicy(
		_CTServerConnectionCreate(kCFAllocatorDefault, NULL, NULL),
		NSBundle.mainBundle.bundleIdentifier,
		@{
			@"kCTCellularDataUsagePolicy" : @"kCTCellularDataUsagePolicyAlwaysAllow",
			@"kCTWiFiDataUsagePolicy" : @"kCTCellularDataUsagePolicyAlwaysAllow"
		}
	);
}

NSString *getExecutablePath(void)
{
	uint32_t len = PATH_MAX;
	char selfPath[len];
	_NSGetExecutablePath(selfPath, &len);
	return [NSString stringWithUTF8String:selfPath];
}

#ifdef EMBEDDED_ROOT_HELPER
NSString* rootHelperPath(void)
{
	return getExecutablePath();
}
#else
NSString* rootHelperPath(void)
{
	return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"trollstorehelper"];
}
#endif

int fd_is_valid(int fd)
{
	return fcntl(fd, F_GETFD) != -1 || errno != EBADF;
}

NSString* getNSStringFromFile(int fd)
{
	NSMutableString* ms = [NSMutableString new];
	ssize_t num_read;
	char c;
	if(!fd_is_valid(fd)) return @"";
	while((num_read = read(fd, &c, sizeof(c))))
	{
		[ms appendString:[NSString stringWithFormat:@"%c", c]];
		if(c == '\n') break;
	}
	return ms.copy;
}

void printMultilineNSString(NSString* stringToPrint)
{
	NSCharacterSet *separator = [NSCharacterSet newlineCharacterSet];
	NSArray* lines = [stringToPrint componentsSeparatedByCharactersInSet:separator];
	for(NSString* line in lines)
	{
		NSLog(@"%@", line);
	}
}

int spawnRoot(NSString* path, NSArray* args, NSString** stdOut, NSString** stdErr)
{
	NSMutableArray* argsM = args.mutableCopy ?: [NSMutableArray new];
	[argsM insertObject:path atIndex:0];
	
	NSUInteger argCount = [argsM count];
	char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));

	for (NSUInteger i = 0; i < argCount; i++)
	{
		argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
	}
	argsC[argCount] = NULL;

	posix_spawnattr_t attr;
	posix_spawnattr_init(&attr);

	posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
	posix_spawnattr_set_persona_uid_np(&attr, 0);
	posix_spawnattr_set_persona_gid_np(&attr, 0);

	posix_spawn_file_actions_t action;
	posix_spawn_file_actions_init(&action);

	int outErr[2];
	if(stdErr)
	{
		pipe(outErr);
		posix_spawn_file_actions_adddup2(&action, outErr[1], STDERR_FILENO);
		posix_spawn_file_actions_addclose(&action, outErr[0]);
	}

	int out[2];
	if(stdOut)
	{
		pipe(out);
		posix_spawn_file_actions_adddup2(&action, out[1], STDOUT_FILENO);
		posix_spawn_file_actions_addclose(&action, out[0]);
	}
	
	pid_t task_pid;
	int status = -200;
	int spawnError = posix_spawn(&task_pid, [path UTF8String], &action, &attr, (char* const*)argsC, NULL);
	posix_spawnattr_destroy(&attr);
	for (NSUInteger i = 0; i < argCount; i++)
	{
		free(argsC[i]);
	}
	free(argsC);
	
	if(spawnError != 0)
	{
		NSLog(@"posix_spawn error %d\n", spawnError);
		return spawnError;
	}

	__block volatile BOOL _isRunning = YES;
	NSMutableString* outString = [NSMutableString new];
	NSMutableString* errString = [NSMutableString new];
	dispatch_semaphore_t sema = 0;
	dispatch_queue_t logQueue;
	if(stdOut || stdErr)
	{
		logQueue = dispatch_queue_create("com.opa334.TrollStore.LogCollector", NULL);
		sema = dispatch_semaphore_create(0);

		int outPipe = out[0];
		int outErrPipe = outErr[0];

		__block BOOL outEnabled = (BOOL)stdOut;
		__block BOOL errEnabled = (BOOL)stdErr;
		dispatch_async(logQueue, ^
		{
			while(_isRunning)
			{
				@autoreleasepool
				{
					if(outEnabled)
					{
						[outString appendString:getNSStringFromFile(outPipe)];
					}
					if(errEnabled)
					{
						[errString appendString:getNSStringFromFile(outErrPipe)];
					}
				}
			}
			dispatch_semaphore_signal(sema);
		});
	}

	do
	{
		if (waitpid(task_pid, &status, 0) != -1) {
			NSLog(@"Child status %d", WEXITSTATUS(status));
		} else
		{
			perror("waitpid");
			_isRunning = NO;
			return -222;
		}
	} while (!WIFEXITED(status) && !WIFSIGNALED(status));

	_isRunning = NO;
	if(stdOut || stdErr)
	{
		if(stdOut)
		{
			close(out[1]);
		}
		if(stdErr)
		{
			close(outErr[1]);
		}

		// wait for logging queue to finish
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		if(stdOut)
		{
			*stdOut = outString.copy;
		}
		if(stdErr)
		{
			*stdErr = errString.copy;
		}
	}

	return WEXITSTATUS(status);
}

void enumerateProcessesUsingBlock(void (^enumerator)(pid_t pid, NSString* executablePath, BOOL* stop))
{
	static int maxArgumentSize = 0;
	if (maxArgumentSize == 0) {
		size_t size = sizeof(maxArgumentSize);
		if (sysctl((int[]){ CTL_KERN, KERN_ARGMAX }, 2, &maxArgumentSize, &size, NULL, 0) == -1) {
			perror("sysctl argument size");
			maxArgumentSize = 4096; // Default
		}
	}
	int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL};
	struct kinfo_proc *info;
	size_t length;
	int count;
	
	if (sysctl(mib, 3, NULL, &length, NULL, 0) < 0)
		return;
	if (!(info = malloc(length)))
		return;
	if (sysctl(mib, 3, info, &length, NULL, 0) < 0) {
		free(info);
		return;
	}
	count = length / sizeof(struct kinfo_proc);
	for (int i = 0; i < count; i++) {
		@autoreleasepool {
		pid_t pid = info[i].kp_proc.p_pid;
		if (pid == 0) {
			continue;
		}
		size_t size = maxArgumentSize;
		char* buffer = (char *)malloc(length);
		if (sysctl((int[]){ CTL_KERN, KERN_PROCARGS2, pid }, 3, buffer, &size, NULL, 0) == 0) {
			NSString* executablePath = [NSString stringWithCString:(buffer+sizeof(int)) encoding:NSUTF8StringEncoding];
			
			BOOL stop = NO;
			enumerator(pid, executablePath, &stop);
			if(stop)
			{
				free(buffer);
				break;
			}
		}
		free(buffer);
		}
	}
	free(info);
}

void killall(NSString* processName, BOOL softly)
{
	enumerateProcessesUsingBlock(^(pid_t pid, NSString* executablePath, BOOL* stop)
	{
		if([executablePath.lastPathComponent isEqualToString:processName])
		{
			if(softly)
			{
				kill(pid, SIGTERM);
			}
			else
			{
				kill(pid, SIGKILL);
			}
		}
	});
}

void respring(void)
{
	killall(@"SpringBoard", YES);
	exit(0);
}

void github_fetchLatestVersion(NSString* repo, void (^completionHandler)(NSString* latestVersion))
{
	NSString* urlString = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/latest", repo];
	NSURL* githubLatestAPIURL = [NSURL URLWithString:urlString];

	NSURLSessionDataTask* task = [NSURLSession.sharedSession dataTaskWithURL:githubLatestAPIURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
	{
		if(!error)
		{
			if ([response isKindOfClass:[NSHTTPURLResponse class]])
			{
				NSError *jsonError;
				NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

				if (!jsonError)
				{
					completionHandler(jsonResponse[@"tag_name"]);
				}
			}
		}
	}];

	[task resume];
}

void fetchLatestTrollStoreVersion(void (^completionHandler)(NSString* latestVersion))
{
	github_fetchLatestVersion(@"opa334/TrollStore", completionHandler);
}

void fetchLatestLdidVersion(void (^completionHandler)(NSString* latestVersion))
{
	github_fetchLatestVersion(@"opa334/ldid", completionHandler);
}

NSArray* trollStoreInstalledAppContainerPaths()
{
	NSMutableArray* appContainerPaths = [NSMutableArray new];

	NSString* appContainersPath = @"/var/containers/Bundle/Application";

	NSError* error;
	NSArray* containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainersPath error:&error];
	if(error)
	{
		NSLog(@"error getting app bundles paths %@", error);
	}
	if(!containers) return nil;
	
	for(NSString* container in containers)
	{
		NSString* containerPath = [appContainersPath stringByAppendingPathComponent:container];
		BOOL isDirectory = NO;
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:containerPath isDirectory:&isDirectory];
		if(exists && isDirectory)
		{
			NSString* trollStoreMark = [containerPath stringByAppendingPathComponent:@"_TrollStore"];
			if([[NSFileManager defaultManager] fileExistsAtPath:trollStoreMark])
			{
				NSString* trollStoreApp = [containerPath stringByAppendingPathComponent:@"TrollStore.app"];
				if(![[NSFileManager defaultManager] fileExistsAtPath:trollStoreApp])
				{
					[appContainerPaths addObject:containerPath];
				}
			}
		}
	}

	return appContainerPaths.copy;
}

NSArray* trollStoreInstalledAppBundlePaths()
{
	NSMutableArray* appPaths = [NSMutableArray new];
	for(NSString* containerPath in trollStoreInstalledAppContainerPaths())
	{
		NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:containerPath error:nil];
		if(!items) return nil;
		
		for(NSString* item in items)
		{
			if([item.pathExtension isEqualToString:@"app"])
			{
				[appPaths addObject:[containerPath stringByAppendingPathComponent:item]];
			}
		}
	}
	return appPaths.copy;
}

NSString* trollStorePath()
{
	NSError* mcmError;
	MCMAppContainer* appContainer = [MCMAppContainer containerWithIdentifier:@"com.opa334.TrollStore" createIfNecessary:NO existed:NULL error:&mcmError];
	if(!appContainer) return nil;
	return appContainer.url.path;
}

NSString* trollStoreAppPath()
{
	return [trollStorePath() stringByAppendingPathComponent:@"TrollStore.app"];
}

BOOL isRemovableSystemApp(NSString* appId)
{
	return [[NSFileManager defaultManager] fileExistsAtPath:[@"/System/Library/AppSignatures" stringByAppendingPathComponent:appId]];
}

LSApplicationProxy* findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE allowedTypes)
{
	__block LSApplicationProxy* outProxy;

	void (^searchBlock)(LSApplicationProxy* appProxy) = ^(LSApplicationProxy* appProxy)
	{
		if(appProxy.installed && !appProxy.restricted)
		{
			if([appProxy.bundleURL.path hasPrefix:@"/private/var/containers"])
			{
				NSURL* trollStorePersistenceMarkURL = [appProxy.bundleURL URLByAppendingPathComponent:@".TrollStorePersistenceHelper"];
				if([trollStorePersistenceMarkURL checkResourceIsReachableAndReturnError:nil])
				{
					outProxy = appProxy;
				}
			}
		}
	};

	if(allowedTypes & PERSISTENCE_HELPER_TYPE_USER)
	{
		[[LSApplicationWorkspace defaultWorkspace] enumerateApplicationsOfType:0 block:searchBlock];
	}
	if(allowedTypes & PERSISTENCE_HELPER_TYPE_SYSTEM)
	{
		[[LSApplicationWorkspace defaultWorkspace] enumerateApplicationsOfType:1 block:searchBlock];
	}

	return outProxy;
}

SecStaticCodeRef getStaticCodeRef(NSString *binaryPath)
{
	if(binaryPath == nil)
	{
		return NULL;
	}
	
	CFURLRef binaryURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)binaryPath, kCFURLPOSIXPathStyle, false);
	if(binaryURL == NULL)
	{
		NSLog(@"[getStaticCodeRef] failed to get URL to binary %@", binaryPath);
		return NULL;
	}
	
	SecStaticCodeRef codeRef = NULL;
	OSStatus result;
	
	result = SecStaticCodeCreateWithPathAndAttributes(binaryURL, kSecCSDefaultFlags, NULL, &codeRef);
	
	CFRelease(binaryURL);
	
	if(result != errSecSuccess)
	{
		NSLog(@"[getStaticCodeRef] failed to create static code for binary %@", binaryPath);
		return NULL;
	}
		
	return codeRef;
}

NSDictionary* dumpEntitlements(SecStaticCodeRef codeRef)
{
	if(codeRef == NULL)
	{
		NSLog(@"[dumpEntitlements] attempting to dump entitlements without a StaticCodeRef");
		return nil;
	}
	
	CFDictionaryRef signingInfo = NULL;
	OSStatus result;
	
	result = SecCodeCopySigningInformation(codeRef, kSecCSRequirementInformation, &signingInfo);
	
	if(result != errSecSuccess)
	{
		NSLog(@"[dumpEntitlements] failed to copy signing info from static code");
		return nil;
	}
	
	NSDictionary *entitlementsNSDict = nil;
	
	CFDictionaryRef entitlements = CFDictionaryGetValue(signingInfo, kSecCodeInfoEntitlementsDict);
	if(entitlements == NULL)
	{
		NSLog(@"[dumpEntitlements] no entitlements specified");
	}
	else if(CFGetTypeID(entitlements) != CFDictionaryGetTypeID())
	{
		NSLog(@"[dumpEntitlements] invalid entitlements");
	}
	else
	{
		entitlementsNSDict = (__bridge NSDictionary *)(entitlements);
		NSLog(@"[dumpEntitlements] dumped %@", entitlementsNSDict);
	}
	
	CFRelease(signingInfo);
	return entitlementsNSDict;
}

NSDictionary* dumpEntitlementsFromBinaryAtPath(NSString *binaryPath)
{
	// This function is intended for one-shot checks. Main-event functions should retain/release their own SecStaticCodeRefs
	
	if(binaryPath == nil)
	{
		return nil;
	}
	
	SecStaticCodeRef codeRef = getStaticCodeRef(binaryPath);
	if(codeRef == NULL)
	{
		return nil;
	}
	
	NSDictionary *entitlements = dumpEntitlements(codeRef);
	CFRelease(codeRef);

	return entitlements;
}

NSDictionary* dumpEntitlementsFromBinaryData(NSData* binaryData)
{
	NSDictionary* entitlements;
	NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	NSURL* tmpURL = [NSURL fileURLWithPath:tmpPath];
	if([binaryData writeToURL:tmpURL options:NSDataWritingAtomic error:nil])
	{
		entitlements = dumpEntitlementsFromBinaryAtPath(tmpPath);
		[[NSFileManager defaultManager] removeItemAtURL:tmpURL error:nil];
	}
	return entitlements;
}

EXPLOIT_TYPE getDeclaredExploitTypeFromInfoDictionary(NSDictionary *infoDict)
{
    NSObject *tsPreAppliedExploitType = infoDict[@"TSPreAppliedExploitType"];
    if([tsPreAppliedExploitType isKindOfClass:[NSNumber class]])
    {
        NSNumber *tsPreAppliedExploitTypeNum = (NSNumber *)tsPreAppliedExploitType;
        int exploitTypeInt = [tsPreAppliedExploitTypeNum intValue];

        if(exploitTypeInt > 0)
        {
            // Convert versions 1, 2, etc... for use with bitmasking
            return (1 << (exploitTypeInt - 1));
        }
        else
        {
            NSLog(@"[getDeclaredExploitTypeFromInfoDictionary] rejecting TSPreAppliedExploitType Info.plist value (%i) which is out of range", exploitTypeInt);
        }
    }

    // Legacy Info.plist flag - now deprecated, but we treat it as a custom root cert if present
    NSObject *tsBundleIsPreSigned = infoDict[@"TSBundlePreSigned"];
    if([tsBundleIsPreSigned isKindOfClass:[NSNumber class]])
    {
        NSNumber *tsBundleIsPreSignedNum = (NSNumber *)tsBundleIsPreSigned;
        if([tsBundleIsPreSignedNum boolValue] == YES)
        {
            return EXPLOIT_TYPE_CUSTOM_ROOT_CERTIFICATE_V1;
        }
    }

    // No declarations
    return 0;
}

void determinePlatformVulnerableExploitTypes(void *context) {
	size_t size = 0;

	// Get the current build number
	int mib[2] = {CTL_KERN, KERN_OSVERSION};

	// Get size of buffer
	sysctl(mib, 2, NULL, &size, NULL, 0);

	// Get the actual value
	char *os_build = malloc(size);
	if(!os_build)
	{
		// malloc failed
		perror("malloc buffer for KERN_OSVERSION");
		return;
	}

	if (sysctl(mib, 2, os_build, &size, NULL, 0) != 0)
	{
		// sysctl failed
		perror("sysctl KERN_OSVERSION");
		free(os_build);
		return;
	}


	if(strncmp(os_build, "19F5070b", 8) <= 0)
	{
		// iOS 14.0 - 15.5 beta 4
		gPlatformVulnerabilities = (EXPLOIT_TYPE_CUSTOM_ROOT_CERTIFICATE_V1 | EXPLOIT_TYPE_CMS_SIGNERINFO_V1);
	}
	else if(strncmp(os_build, "19G5027e", 8) >= 0 && strncmp(os_build, "19G5063a", 8) <= 0)
	{
		// iOS 15.6 beta 1 - 5
		gPlatformVulnerabilities = (EXPLOIT_TYPE_CUSTOM_ROOT_CERTIFICATE_V1 | EXPLOIT_TYPE_CMS_SIGNERINFO_V1);
	}
	else if(strncmp(os_build, "20H18", 5) <= 0)
	{
		// iOS 14.0 - 16.6.1, 16.7 RC
		gPlatformVulnerabilities = EXPLOIT_TYPE_CMS_SIGNERINFO_V1;
	}
	else if(strncmp(os_build, "21A5248v", 8) >= 0 && strncmp(os_build, "21A331", 6) <= 0)
	{
		// iOS 17.0
		gPlatformVulnerabilities = EXPLOIT_TYPE_CMS_SIGNERINFO_V1;
	}

	free(os_build);
}

bool isPlatformVulnerableToExploitType(EXPLOIT_TYPE exploitType) {
	// Find out what we are vulnerable to
	static dispatch_once_t once;
	dispatch_once_f(&once, NULL, determinePlatformVulnerableExploitTypes);

	return (exploitType & gPlatformVulnerabilities) != 0;
}
