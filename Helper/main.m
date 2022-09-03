#import <stdio.h>
#import "unarchive.h"
@import Foundation;
#import "uicache.h"
#import <sys/stat.h>
#import <dlfcn.h>
#import <spawn.h>
#import <objc/runtime.h>
#import "CoreServices.h"
#import "Shared.h"

#import <SpringBoardServices/SpringBoardServices.h>

extern mach_msg_return_t SBReloadIconForIdentifier(mach_port_t machport, const char* identifier);
@interface SBSHomeScreenService : NSObject
- (void)reloadIcons;
@end
extern NSString* BKSActivateForEventOptionTypeBackgroundContentFetching;
extern NSString* BKSOpenApplicationOptionKeyActivateForEvent;

extern void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

#define kCFPreferencesNoContainer CFSTR("kCFPreferencesNoContainer")

typedef CFPropertyListRef (*_CFPreferencesCopyValueWithContainerType)(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef void (*_CFPreferencesSetValueWithContainerType)(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef Boolean (*_CFPreferencesSynchronizeWithContainerType)(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef CFArrayRef (*_CFPreferencesCopyKeyListWithContainerType)(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef CFDictionaryRef (*_CFPreferencesCopyMultipleWithContainerType)(CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);

BOOL _installPersistenceHelper(LSApplicationProxy* appProxy, NSString* sourcePersistenceHelper, NSString* sourceRootHelper);

extern char*** _NSGetArgv();
NSString* safe_getExecutablePath()
{
	char* executablePathC = **_NSGetArgv();
	return [NSString stringWithUTF8String:executablePathC];
}

NSDictionary* infoDictionaryForAppPath(NSString* appPath)
{
	NSString* infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	return [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
}

NSString* appIdForAppPath(NSString* appPath)
{
	return infoDictionaryForAppPath(appPath)[@"CFBundleIdentifier"];
}

NSString* appPathForAppId(NSString* appId, NSError** error)
{
	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		if([appIdForAppPath(appPath) isEqualToString:appId])
		{
			return appPath;
		}
	}
	return nil;
}

static NSString* getNSStringFromFile(int fd)
{
	NSMutableString* ms = [NSMutableString new];
	ssize_t num_read;
	char c;
	while((num_read = read(fd, &c, sizeof(c))))
	{
		[ms appendString:[NSString stringWithFormat:@"%c", c]];
	}
	return ms.copy;
}

static void printMultilineNSString(NSString* stringToPrint)
{
	NSCharacterSet *separator = [NSCharacterSet newlineCharacterSet];
	NSArray* lines = [stringToPrint componentsSeparatedByCharactersInSet:separator];
	for(NSString* line in lines)
	{
		NSLog(@"%@", line);
	}
}

void installLdid(NSString* ldidToCopyPath)
{
	if(![[NSFileManager defaultManager] fileExistsAtPath:ldidToCopyPath]) return;

	NSString* ldidPath = [trollStoreAppPath() stringByAppendingPathComponent:@"ldid"];
	if([[NSFileManager defaultManager] fileExistsAtPath:ldidPath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:ldidPath error:nil];
	}

	[[NSFileManager defaultManager] copyItemAtPath:ldidToCopyPath toPath:ldidPath error:nil];

	chmod(ldidPath.UTF8String, 0755);
	chown(ldidPath.UTF8String, 0, 0);
}

BOOL isLdidInstalled(void)
{
	NSString* ldidPath = [trollStoreAppPath() stringByAppendingPathComponent:@"ldid"];
	return [[NSFileManager defaultManager] fileExistsAtPath:ldidPath];
}

int runLdid(NSArray* args, NSString** output, NSString** errorOutput)
{
	NSString* ldidPath = [trollStoreAppPath() stringByAppendingPathComponent:@"ldid"];
	NSMutableArray* argsM = args.mutableCopy ?: [NSMutableArray new];
	[argsM insertObject:ldidPath.lastPathComponent atIndex:0];

	NSUInteger argCount = [argsM count];
	char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));

	for (NSUInteger i = 0; i < argCount; i++)
	{
		argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
	}
	argsC[argCount] = NULL;

	posix_spawn_file_actions_t action;
	posix_spawn_file_actions_init(&action);

	int outErr[2];
	pipe(outErr);
	posix_spawn_file_actions_adddup2(&action, outErr[1], STDERR_FILENO);
	posix_spawn_file_actions_addclose(&action, outErr[0]);

	int out[2];
	pipe(out);
	posix_spawn_file_actions_adddup2(&action, out[1], STDOUT_FILENO);
	posix_spawn_file_actions_addclose(&action, out[0]);
	
	pid_t task_pid;
	int status = -200;
	int spawnError = posix_spawn(&task_pid, [ldidPath UTF8String], &action, NULL, (char* const*)argsC, NULL);
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

	do
	{
		if (waitpid(task_pid, &status, 0) != -1) {
			//printf("Child status %dn", WEXITSTATUS(status));
		} else
		{
			perror("waitpid");
			return -222;
		}
	} while (!WIFEXITED(status) && !WIFSIGNALED(status));

	close(outErr[1]);
	close(out[1]);

	NSString* ldidOutput = getNSStringFromFile(out[0]);
	if(output)
	{
		*output = ldidOutput;
	}

	NSString* ldidErrorOutput = getNSStringFromFile(outErr[0]);
	if(errorOutput)
	{
		*errorOutput = ldidErrorOutput;
	}

	return WEXITSTATUS(status);
}

NSString* dumpEntitlements(NSString* binaryPath)
{
	NSString* output;
	NSString* errorOutput;

	int ldidRet = runLdid(@[@"-e", binaryPath], &output, &errorOutput);

	NSLog(@"entitlements dump exited with status %d", ldidRet);
	
	NSLog(@"- dump error output start -");

	printMultilineNSString(errorOutput);

	NSLog(@"- dump error output end -");

	NSLog(@"- dumped entitlements output start -");

	printMultilineNSString(output);

	NSLog(@"- dumped entitlements output end -");

	return output;
}

BOOL signApp(NSString* appPath, NSError** error)
{
	if(!isLdidInstalled()) return NO;

	NSDictionary* appInfoDict = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
	if(!appInfoDict) return NO;

	NSString* executable = appInfoDict[@"CFBundleExecutable"];
	NSString* executablePath = [appPath stringByAppendingPathComponent:executable];

	if(![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) return NO;

	NSString* certPath = [trollStoreAppPath() stringByAppendingPathComponent:@"cert.p12"];
	NSString* certArg = [@"-K" stringByAppendingPathComponent:certPath];
	NSString* errorOutput;
	int ldidRet;

	NSString* entitlements = dumpEntitlements(executablePath);
	if(entitlements.length == 0)
	{
		NSLog(@"app main binary has no entitlements, signing app with fallback entitlements...");
		// app has no entitlements, sign with fallback entitlements
		NSString* entitlementPath = [trollStoreAppPath() stringByAppendingPathComponent:@"fallback.entitlements"];
		NSString* entitlementArg = [@"-S" stringByAppendingString:entitlementPath];
		ldidRet = runLdid(@[entitlementArg, certArg, appPath], nil, &errorOutput);
	}
	else
	{
		// app has entitlements, keep them
		ldidRet = runLdid(@[@"-S", @"-M", certArg, appPath], nil, &errorOutput);
	}

	NSLog(@"ldid exited with status %d", ldidRet);

	NSLog(@"- ldid error output start -");

	printMultilineNSString(errorOutput);

	NSLog(@"- ldid error output end -");

	return ldidRet == 0;
}

// 170: failed to create container for app bundle
// 171: a non trollstore app with the same identifier is already installled
// 172: no info.plist found in app
int installApp(NSString* appPath, BOOL sign, NSError** error)
{
	NSString* appId = appIdForAppPath(appPath);
	if(!appId) return 172;

	if(sign)
	{
		// if it fails to sign, we don't care
		signApp(appPath, error);
	}

	BOOL existed;
	NSError* mcmError;
	MCMAppContainer* appContainer = [objc_getClass("MCMAppContainer") containerWithIdentifier:appId createIfNecessary:YES existed:&existed error:&mcmError];
	NSLog(@"[installApp] appContainer: %@, mcmError: %@", appContainer, mcmError);
	if(!appContainer || mcmError)
	{
		if(error) *error = mcmError;
		return 170;
	}

	// check if the bundle is empty
	BOOL isEmpty = YES;
	NSArray* bundleItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainer.url.path error:error];
	for(NSString* bundleItem in bundleItems)
	{
		if([bundleItem.pathExtension isEqualToString:@"app"])
		{
			isEmpty = NO;
			break;
		}
	}

	// Make sure there isn't already an app store app installed with the same identifier
	NSURL* trollStoreMarkURL = [appContainer.url URLByAppendingPathComponent:@"_TrollStore"];
	if(existed && !isEmpty && ![trollStoreMarkURL checkResourceIsReachableAndReturnError:nil])
	{
		NSLog(@"[installApp] already installed and not a TrollStore app... bailing out");
		return 171;
	}

	// Apply correct permissions
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appPath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
	NSURL* fileURL;
	while(fileURL = [enumerator nextObject])
	{
		NSString* filePath = fileURL.path;
		chown(filePath.UTF8String, 33, 33);
		if([filePath.lastPathComponent isEqualToString:@"Info.plist"])
		{
			NSDictionary* infoDictionary = [NSDictionary dictionaryWithContentsOfFile:filePath];
			NSString* executable = infoDictionary[@"CFBundleExecutable"];
			if(executable)
			{
				NSString* executablePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:executable];
				chmod(executablePath.UTF8String, 0755);
			}
		}
		else if([filePath.pathExtension isEqualToString:@"dylib"])
		{
			chmod(filePath.UTF8String, 0755);
		}
	}

	// chown 0 all root binaries
	NSDictionary* mainInfoDictionary = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
	if(!mainInfoDictionary) return 172;
	NSObject* tsRootBinaries = mainInfoDictionary[@"TSRootBinaries"];
	if([tsRootBinaries isKindOfClass:[NSArray class]])
	{
		NSArray* tsRootBinariesArr = (NSArray*)tsRootBinaries;
		for(NSObject* rootBinary in tsRootBinariesArr)
		{
			if([rootBinary isKindOfClass:[NSString class]])
			{
				NSString* rootBinaryStr = (NSString*)rootBinary;
				NSString* rootBinaryPath = [appPath stringByAppendingPathComponent:rootBinaryStr];
				if([[NSFileManager defaultManager] fileExistsAtPath:rootBinaryPath])
				{
					chmod(rootBinaryPath.UTF8String, 0755);
					chown(rootBinaryPath.UTF8String, 0, 0);
					NSLog(@"[installApp] applying permissions for root binary %@", rootBinaryPath);
				}
			}
		}
	}

	// Wipe old version if needed
	if(existed)
	{
		NSLog(@"[installApp] found existing TrollStore app, cleaning directory");
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:appContainer.url includingPropertiesForKeys:nil options:0 errorHandler:nil];
		NSURL* fileURL;
		while(fileURL = [enumerator nextObject])
		{
			// do not under any circumstance delete this file as it makes iOS loose the app registration
			if([fileURL.lastPathComponent isEqualToString:@".com.apple.mobile_container_manager.metadata.plist"])
			{
				NSLog(@"[installApp] skip removal of %@", fileURL);
				continue;
			}

			[[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
		}
	}

	// Install app
	NSString* newAppPath = [appContainer.url.path stringByAppendingPathComponent:appPath.lastPathComponent];
	NSLog(@"[installApp] new app path: %@", newAppPath);
	
	BOOL suc = [[NSFileManager defaultManager] copyItemAtPath:appPath toPath:newAppPath error:error];
	if(suc)
	{
		// Mark app as TrollStore app
		[[NSFileManager defaultManager] createFileAtPath:trollStoreMarkURL.path contents:[NSData data] attributes:nil];

		NSLog(@"[installApp] app installed, adding to icon cache now...");
		registerPath((char*)newAppPath.UTF8String, 0);
		return 0;
	}
	else
	{
		return 1;
	}
}

int uninstallApp(NSString* appId, NSError** error)
{
	NSString* appPath = appPathForAppId(appId, error);
	if(!appPath) return 1;

	LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:appId];
	NSLog(@"appProxy: %@", appProxy);


	MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer") containerWithIdentifier:appId createIfNecessary:NO existed:nil error:nil];
	NSString *containerPath = [appContainer url].path;
	if(containerPath)
	{
		NSLog(@"deleting %@", containerPath);
		// delete app container path
		[[NSFileManager defaultManager] removeItemAtPath:containerPath error:error];
	}

	// delete group container paths
	for(NSURL* groupURL in [appProxy groupContainerURLs])
	{
		[[NSFileManager defaultManager] removeItemAtPath:groupURL.path error:error];
		NSLog(@"deleting %@", groupURL.path);
	}

	// delete app plugin paths
	for(LSPlugInKitProxy* pluginProxy in appProxy.plugInKitPlugins)
	{
		NSURL* pluginURL = pluginProxy.dataContainerURL;
		if(pluginURL)
		{
			[[NSFileManager defaultManager] removeItemAtPath:pluginURL.path error:error];
			NSLog(@"deleting %@", pluginURL.path);
		}
	}

	// unregister app
	registerPath((char*)appPath.UTF8String, 1);
	NSLog(@"deleting %@", [appPath stringByDeletingLastPathComponent]);

	// delete app
	BOOL deleteSuc = [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByDeletingLastPathComponent] error:error];
	if(deleteSuc)
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

// 166: IPA does not exist or is not accessible
// 167: IPA does not appear to contain an app

int installIpa(NSString* ipaPath, NSError** error)
{
	if(![[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) return 166;

	BOOL suc = NO;
	NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	
	suc = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:NO attributes:nil error:error];
	if(!suc) return 1;

	extract(ipaPath, tmpPath);

	NSString* tmpPayloadPath = [tmpPath stringByAppendingPathComponent:@"Payload"];
	
	NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPayloadPath error:error];
	if(!items) return 167;
	
	NSString* tmpAppPath;
	for(NSString* item in items)
	{
		if([item.pathExtension isEqualToString:@"app"])
		{
			tmpAppPath = [tmpPayloadPath stringByAppendingPathComponent:item];
			break;
		}
	}
	if(!tmpAppPath) return 167;
	
	int ret = installApp(tmpAppPath, YES, error);
	
	[[NSFileManager defaultManager] removeItemAtPath:tmpAppPath error:nil];

	return ret;
}

void uninstallAllApps(void)
{
	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		uninstallApp(appIdForAppPath(appPath), nil);
	}
}

BOOL uninstallTrollStore(BOOL unregister)
{
	NSString* trollStore = trollStorePath();
	if(![[NSFileManager defaultManager] fileExistsAtPath:trollStore]) return NO;

	if(unregister)
	{
		registerPath((char*)trollStoreAppPath().UTF8String, 1);
	}

	return [[NSFileManager defaultManager] removeItemAtPath:trollStore error:nil];
}

BOOL installTrollStore(NSString* pathToTar)
{
	//_CFPreferencesCopyValueWithContainerType _CFPreferencesCopyValueWithContainer = (_CFPreferencesCopyValueWithContainerType)dlsym(RTLD_DEFAULT, "_CFPreferencesCopyValueWithContainer");
	_CFPreferencesSetValueWithContainerType _CFPreferencesSetValueWithContainer = (_CFPreferencesSetValueWithContainerType)dlsym(RTLD_DEFAULT, "_CFPreferencesSetValueWithContainer");
	_CFPreferencesSynchronizeWithContainerType _CFPreferencesSynchronizeWithContainer = (_CFPreferencesSynchronizeWithContainerType)dlsym(RTLD_DEFAULT, "_CFPreferencesSynchronizeWithContainer");

	/*CFPropertyListRef SBShowNonDefaultSystemAppsValue = _CFPreferencesCopyValueWithContainer(CFSTR("SBShowNonDefaultSystemApps"), CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
	if(SBShowNonDefaultSystemAppsValue != kCFBooleanTrue)
	{*/
		_CFPreferencesSetValueWithContainer(CFSTR("SBShowNonDefaultSystemApps"), kCFBooleanTrue, CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
		_CFPreferencesSynchronizeWithContainer(CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
		//NSLog(@"unrestricted springboard apps");
	/*}*/


	if(![[NSFileManager defaultManager] fileExistsAtPath:pathToTar]) return 1;
	if(![pathToTar.pathExtension isEqualToString:@"tar"]) return 1;

	NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	BOOL suc = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:NO attributes:nil error:nil];
	if(!suc) return 1;

	extract(pathToTar, tmpPath);

	NSString* tmpTrollStore = [tmpPath stringByAppendingPathComponent:@"TrollStore.app"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:tmpTrollStore]) return 1;

	// Save existing ldid installation if it exists
	NSString* existingLdidPath = [trollStoreAppPath() stringByAppendingPathComponent:@"ldid"];
	if([[NSFileManager defaultManager] fileExistsAtPath:existingLdidPath])
	{
		NSString* tmpLdidPath = [tmpTrollStore stringByAppendingPathComponent:@"ldid"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpLdidPath])
		{
			[[NSFileManager defaultManager] copyItemAtPath:existingLdidPath toPath:tmpLdidPath error:nil];
		}
	}

	// Update persistence helper if installed
	LSApplicationProxy* persistenceHelperApp = findPersistenceHelperApp();
	if(persistenceHelperApp)
	{
		NSString* trollStorePersistenceHelper = [tmpTrollStore stringByAppendingPathComponent:@"PersistenceHelper"];
		NSString* trollStoreRootHelper = [tmpTrollStore stringByAppendingPathComponent:@"trollstorehelper"];
		_installPersistenceHelper(persistenceHelperApp, trollStorePersistenceHelper, trollStoreRootHelper);
	}

	return installApp(tmpTrollStore, NO, nil);;
}

void refreshAppRegistrations()
{
	//registerPath((char*)trollStoreAppPath().UTF8String, 1);
	registerPath((char*)trollStoreAppPath().UTF8String, 0);

	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		//registerPath((char*)appPath.UTF8String, 1);
		registerPath((char*)appPath.UTF8String, 0);
	}
}

BOOL _installPersistenceHelper(LSApplicationProxy* appProxy, NSString* sourcePersistenceHelper, NSString* sourceRootHelper)
{
	NSLog(@"_installPersistenceHelper(%@, %@, %@)", appProxy, sourcePersistenceHelper, sourceRootHelper);

	NSString* executablePath = appProxy.canonicalExecutablePath;
	NSString* bundlePath = appProxy.bundleURL.path;
	if(!executablePath)
	{
		NSBundle* appBundle = [NSBundle bundleWithPath:bundlePath];
		executablePath = [bundlePath stringByAppendingPathComponent:[appBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]];
	}

	NSString* markPath = [bundlePath stringByAppendingPathComponent:@".TrollStorePersistenceHelper"];
	NSString* helperPath = [bundlePath stringByAppendingPathComponent:@"trollstorehelper"];

	// remove existing persistence helper binary if exists
	if([[NSFileManager defaultManager] fileExistsAtPath:markPath] && [[NSFileManager defaultManager] fileExistsAtPath:executablePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:executablePath error:nil];
	}

	// remove existing root helper binary if exists
	if([[NSFileManager defaultManager] fileExistsAtPath:helperPath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:helperPath error:nil];
	}

	// install new persistence helper binary
	if(![[NSFileManager defaultManager] copyItemAtPath:sourcePersistenceHelper toPath:executablePath error:nil])
	{
		return NO;
	}

	chmod(executablePath.UTF8String, 0755);
	chown(executablePath.UTF8String, 33, 33);

	NSError* error;
	if(![[NSFileManager defaultManager] copyItemAtPath:sourceRootHelper toPath:helperPath error:&error])
	{
		NSLog(@"error copying root helper: %@", error);
	}

	chmod(helperPath.UTF8String, 0755);
	chown(helperPath.UTF8String, 0, 0);

	// mark system app as persistence helper
	if(![[NSFileManager defaultManager] fileExistsAtPath:markPath])
	{
		[[NSFileManager defaultManager] createFileAtPath:markPath contents:[NSData data] attributes:nil];
	}

	return YES;
}

void installPersistenceHelper(NSString* systemAppId)
{
	if(findPersistenceHelperApp()) return;

	NSString* persistenceHelperBinary = [trollStoreAppPath() stringByAppendingPathComponent:@"PersistenceHelper"];
	NSString* rootHelperBinary = [trollStoreAppPath() stringByAppendingPathComponent:@"trollstorehelper"];
	LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:systemAppId];
	if(!appProxy || ![appProxy.bundleType isEqualToString:@"System"]) return;

	NSString* executablePath = appProxy.canonicalExecutablePath;
	NSString* bundlePath = appProxy.bundleURL.path;
	NSString* backupPath = [bundlePath stringByAppendingPathComponent:[[executablePath lastPathComponent] stringByAppendingString:@"_TROLLSTORE_BACKUP"]];

	if([[NSFileManager defaultManager] fileExistsAtPath:backupPath]) return;

	if(![[NSFileManager defaultManager] moveItemAtPath:executablePath toPath:backupPath error:nil]) return;

	if(!_installPersistenceHelper(appProxy, persistenceHelperBinary, rootHelperBinary))
	{
		[[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:executablePath error:nil];
		return;
	}

	BKSTerminateApplicationForReasonAndReportWithDescription(systemAppId, 5, false, @"TrollStore - Reload persistence helper");
}

void uninstallPersistenceHelper(void)
{
	LSApplicationProxy* appProxy = findPersistenceHelperApp();
	if(appProxy)
	{
		NSString* executablePath = appProxy.canonicalExecutablePath;
		NSString* bundlePath = appProxy.bundleURL.path;
		NSString* backupPath = [bundlePath stringByAppendingPathComponent:[[executablePath lastPathComponent] stringByAppendingString:@"_TROLLSTORE_BACKUP"]];
		if(![[NSFileManager defaultManager] fileExistsAtPath:backupPath]) return;

		NSString* helperPath = [bundlePath stringByAppendingPathComponent:@"trollstorehelper"];
		NSString* markPath = [bundlePath stringByAppendingPathComponent:@".TrollStorePersistenceHelper"];

		[[NSFileManager defaultManager] removeItemAtPath:executablePath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:markPath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:helperPath error:nil];

		[[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:executablePath error:nil];

		BKSTerminateApplicationForReasonAndReportWithDescription(appProxy.bundleIdentifier, 5, false, @"TrollStore - Reload persistence helper");
	}
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if(argc <= 1) return -1;

		NSLog(@"trollstore helper go, uid: %d, gid: %d", getuid(), getgid());

		NSBundle* mcmBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/MobileContainerManager.framework"];
		[mcmBundle load];

		int ret = 0;
		NSError* error;

		NSString* cmd = [NSString stringWithUTF8String:argv[1]];
		if([cmd isEqualToString:@"install"])
		{
			if(argc <= 2) return -3;
			NSString* ipaPath = [NSString stringWithUTF8String:argv[2]];
			ret = installIpa(ipaPath, &error);
		} else if([cmd isEqualToString:@"uninstall"])
		{
			if(argc <= 2) return -3;
			NSString* appId = [NSString stringWithUTF8String:argv[2]];
			ret = uninstallApp(appId, &error);
		} else if([cmd isEqualToString:@"install-trollstore"])
		{
			if(argc <= 2) return -3;
			NSString* tsTar = [NSString stringWithUTF8String:argv[2]];
			ret = installTrollStore(tsTar);
			NSLog(@"installed troll store? %d", ret==0);
		} else if([cmd isEqualToString:@"uninstall-trollstore"])
		{
			uninstallAllApps();
			uninstallTrollStore(YES);
		} else if([cmd isEqualToString:@"install-ldid"])
		{
			if(argc <= 2) return -3;
			NSString* ldidPath = [NSString stringWithUTF8String:argv[2]];
			installLdid(ldidPath);
		} else if([cmd isEqualToString:@"refresh"])
		{
			refreshAppRegistrations();
		} else if([cmd isEqualToString:@"refresh-all"])
		{
			[[LSApplicationWorkspace defaultWorkspace] _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:YES];
			refreshAppRegistrations();
		} else if([cmd isEqualToString:@"install-persistence-helper"])
		{
			if(argc <= 2) return -3;
			NSString* systemAppId = [NSString stringWithUTF8String:argv[2]];
			installPersistenceHelper(systemAppId);
		} else if([cmd isEqualToString:@"uninstall-persistence-helper"])
		{
			uninstallPersistenceHelper();
		}

		if(error)
		{
			NSLog(@"error: %@", error);
		}

		NSLog(@"returning %d", ret);

		return ret;
	}
}
