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
#import <sys/utsname.h>

#import <SpringBoardServices/SpringBoardServices.h>
#import <Security/Security.h>


extern mach_msg_return_t SBReloadIconForIdentifier(mach_port_t machport, const char* identifier);
@interface SBSHomeScreenService : NSObject
- (void)reloadIcons;
@end
extern NSString* BKSActivateForEventOptionTypeBackgroundContentFetching;
extern NSString* BKSOpenApplicationOptionKeyActivateForEvent;

extern void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

typedef CF_OPTIONS(uint32_t, SecCSFlags) {
	kSecCSDefaultFlags = 0
};


#define kSecCSRequirementInformation 1 << 2
#define kSecCSSigningInformation 1 << 1

typedef struct __SecCode const *SecStaticCodeRef;

extern CFStringRef kSecCodeInfoEntitlementsDict;
extern CFStringRef kSecCodeInfoCertificates;
extern CFStringRef kSecPolicyAppleiPhoneApplicationSigning;
extern CFStringRef kSecPolicyAppleiPhoneProfileApplicationSigning;
extern CFStringRef kSecPolicyLeafMarkerOid;

OSStatus SecStaticCodeCreateWithPathAndAttributes(CFURLRef path, SecCSFlags flags, CFDictionaryRef attributes, SecStaticCodeRef *staticCode);
OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef *information);
CFDataRef SecCertificateCopyExtensionValue(SecCertificateRef certificate, CFTypeRef extensionOID, bool *isCritical);
void SecPolicySetOptionsValue(SecPolicyRef policy, CFStringRef key, CFTypeRef value);

#define kCFPreferencesNoContainer CFSTR("kCFPreferencesNoContainer")

typedef CFPropertyListRef (*_CFPreferencesCopyValueWithContainerType)(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef void (*_CFPreferencesSetValueWithContainerType)(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef Boolean (*_CFPreferencesSynchronizeWithContainerType)(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef CFArrayRef (*_CFPreferencesCopyKeyListWithContainerType)(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
typedef CFDictionaryRef (*_CFPreferencesCopyMultipleWithContainerType)(CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);

BOOL _installPersistenceHelper(LSApplicationProxy* appProxy, NSString* sourcePersistenceHelper, NSString* sourceRootHelper);

NSArray<LSApplicationProxy*>* applicationsWithGroupId(NSString* groupId)
{
	LSEnumerator* enumerator = [LSEnumerator enumeratorForApplicationProxiesWithOptions:0];
	enumerator.predicate = [NSPredicate predicateWithFormat:@"groupContainerURLs[%@] != nil", groupId];
	return enumerator.allObjects;
}

NSSet<NSString*>* appleURLSchemes(void)
{
	LSEnumerator* enumerator = [LSEnumerator enumeratorForApplicationProxiesWithOptions:0];
	enumerator.predicate = [NSPredicate predicateWithFormat:@"bundleIdentifier BEGINSWITH 'com.apple'"];

	NSMutableSet* systemURLSchemes = [NSMutableSet new];
	LSApplicationProxy* proxy;
	while(proxy = [enumerator nextObject])
	{
		[systemURLSchemes unionSet:proxy.claimedURLSchemes];
	}

	return systemURLSchemes.copy;
}

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

NSString* appMainExecutablePathForAppPath(NSString* appPath)
{
	return [appPath stringByAppendingPathComponent:infoDictionaryForAppPath(appPath)[@"CFBundleExecutable"]];
}

NSString* appPathForAppId(NSString* appId)
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

BOOL certificateHasDataForExtensionOID(SecCertificateRef certificate, CFStringRef oidString)
{
	if(certificate == NULL || oidString == NULL)
	{
		NSLog(@"[certificateHasDataForExtensionOID] attempted to check null certificate or OID");
		return NO;
	}
	
	CFDataRef extensionData = SecCertificateCopyExtensionValue(certificate, oidString, NULL);
	if(extensionData != NULL)
	{
		CFRelease(extensionData);
		return YES;
	}
	
	return NO;
}

BOOL codeCertChainContainsFakeAppStoreExtensions(SecStaticCodeRef codeRef)
{
	if(codeRef == NULL)
	{
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] attempted to check cert chain of null static code object");
		return NO;
	}
	
	CFDictionaryRef signingInfo = NULL;
	OSStatus result;
  
	result = SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation, &signingInfo);

	if(result != errSecSuccess)
	{
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] failed to copy signing info from static code");
		return NO;
	}
	
	CFArrayRef certificates = CFDictionaryGetValue(signingInfo, kSecCodeInfoCertificates);
	if(certificates == NULL || CFArrayGetCount(certificates) == 0)
	{
		return NO;
	}

	// If we match the standard Apple policy, we are signed properly, but we haven't been deliberately signed with a custom root
	
	SecPolicyRef appleAppStorePolicy = SecPolicyCreateWithProperties(kSecPolicyAppleiPhoneApplicationSigning, NULL);

	SecTrustRef trust = NULL;
	SecTrustCreateWithCertificates(certificates, appleAppStorePolicy, &trust);

	if(SecTrustEvaluateWithError(trust, nil))
	{
		CFRelease(trust);
		CFRelease(appleAppStorePolicy);
		CFRelease(signingInfo);
		
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] found certificate extension, but was issued by Apple (App Store)");
		return NO;
	}

	// We haven't matched Apple, so keep going. Is the app profile signed?
		
	CFRelease(appleAppStorePolicy);
	
	SecPolicyRef appleProfileSignedPolicy = SecPolicyCreateWithProperties(kSecPolicyAppleiPhoneProfileApplicationSigning, NULL);
	if(SecTrustSetPolicies(trust, appleProfileSignedPolicy) != errSecSuccess)
	{
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] error replacing trust policy to check for profile-signed app");
		CFRelease(trust);
		CFRelease(signingInfo);
		return NO;
	}
		
	if(SecTrustEvaluateWithError(trust, nil))
	{
		CFRelease(trust);
		CFRelease(appleProfileSignedPolicy);
		CFRelease(signingInfo);
		
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] found certificate extension, but was issued by Apple (profile-signed)");
		return NO;
	}
	
	// Still haven't matched Apple. Are we using a custom root that would take the App Store fastpath?
	CFRelease(appleProfileSignedPolicy);
	
	// Cert chain should be of length 3
	if(CFArrayGetCount(certificates) != 3)
	{
		CFRelease(signingInfo);
		
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] certificate chain length != 3");
		return NO;
	}
		
	// AppleCodeSigning only checks for the codeSigning EKU by default
	SecPolicyRef customRootPolicy = SecPolicyCreateWithProperties(kSecPolicyAppleCodeSigning, NULL);
	SecPolicySetOptionsValue(customRootPolicy, CFSTR("LeafMarkerOid"), CFSTR("1.2.840.113635.100.6.1.3"));
	
	if(SecTrustSetPolicies(trust, customRootPolicy) != errSecSuccess)
	{
		NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] error replacing trust policy to check for custom root");
		CFRelease(trust);
		CFRelease(signingInfo);
		return NO;
	}

	// Need to add our certificate chain to the anchor as it is expected to be a self-signed root
	SecTrustSetAnchorCertificates(trust, certificates);
	
	BOOL evaluatesToCustomAnchor = SecTrustEvaluateWithError(trust, nil);
	NSLog(@"[codeCertChainContainsFakeAppStoreExtensions] app signed with non-Apple certificate %@ using valid custom certificates", evaluatesToCustomAnchor ? @"IS" : @"is NOT");
	
	CFRelease(trust);
	CFRelease(customRootPolicy);
	CFRelease(signingInfo);
	
	return evaluatesToCustomAnchor;
}

int signApp(NSString* appPath)
{
	NSDictionary* appInfoDict = infoDictionaryForAppPath(appPath);
	if(!appInfoDict) return 172;

	NSString* executablePath = appMainExecutablePathForAppPath(appPath);
	if(!executablePath) return 176;

	if(![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) return 174;
	
	NSObject *tsBundleIsPreSigned = appInfoDict[@"TSBundlePreSigned"];
	if([tsBundleIsPreSigned isKindOfClass:[NSNumber class]])
	{
		
		// if TSBundlePreSigned = YES, this bundle has been externally signed so we can skip over signing it now
		NSNumber *tsBundleIsPreSignedNum = (NSNumber *)tsBundleIsPreSigned;
		if([tsBundleIsPreSignedNum boolValue] == YES)
		{
			NSLog(@"[signApp] taking fast path for app which declares it has already been signed (%@)", executablePath);
			return 0;
		}
	}
	
	SecStaticCodeRef codeRef = getStaticCodeRef(executablePath);
	if(codeRef != NULL)
	{
		if(codeCertChainContainsFakeAppStoreExtensions(codeRef))
		{
			NSLog(@"[signApp] taking fast path for app signed using a custom root certificate (%@)", executablePath);
			CFRelease(codeRef);
			return 0;
		}
	}
	else
	{
		NSLog(@"[signApp] failed to get static code, can't derive entitlements from %@, continuing anways...", executablePath);
	}

	if(!isLdidInstalled()) return 173;

	NSString* certPath = [trollStoreAppPath() stringByAppendingPathComponent:@"cert.p12"];
	NSString* certArg = [@"-K" stringByAppendingPathComponent:certPath];
	NSString* errorOutput;
	int ldidRet;

	NSDictionary* entitlements = dumpEntitlements(codeRef);
	CFRelease(codeRef);
	
	if(!entitlements)
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
		ldidRet = runLdid(@[@"-s", certArg, appPath], nil, &errorOutput);
	}

	NSLog(@"ldid exited with status %d", ldidRet);

	NSLog(@"- ldid error output start -");

	printMultilineNSString(errorOutput);

	NSLog(@"- ldid error output end -");

	if(ldidRet == 0)
	{
		return 0;
	}
	else
	{
		return 175;
	}
}

void applyPatchesToInfoDictionary(NSString* appPath)
{
	NSURL* appURL = [NSURL fileURLWithPath:appPath];
	NSURL* infoPlistURL = [appURL URLByAppendingPathComponent:@"Info.plist"];
	NSMutableDictionary* infoDictM = [[NSDictionary dictionaryWithContentsOfURL:infoPlistURL error:nil] mutableCopy];
	if(!infoDictM) return;

	// Enable Notifications
	infoDictM[@"SBAppUsesLocalNotifications"] = @1;

	// Remove system claimed URL schemes if existant
	NSSet* appleSchemes = appleURLSchemes();
	NSArray* CFBundleURLTypes = infoDictM[@"CFBundleURLTypes"];
	if([CFBundleURLTypes isKindOfClass:[NSArray class]])
	{
		NSMutableArray* CFBundleURLTypesM = [NSMutableArray new];

		for(NSDictionary* URLType in CFBundleURLTypes)
		{
			if(![URLType isKindOfClass:[NSDictionary class]]) continue;

			NSMutableDictionary* modifiedURLType = URLType.mutableCopy;
			NSArray* URLSchemes = URLType[@"CFBundleURLSchemes"];
			if(URLSchemes)
			{
				NSMutableSet* URLSchemesSet = [NSMutableSet setWithArray:URLSchemes];
				[URLSchemesSet minusSet:appleSchemes];
				modifiedURLType[@"CFBundleURLSchemes"] = [URLSchemesSet allObjects];
			}
			[CFBundleURLTypesM addObject:modifiedURLType.copy];
		}

		infoDictM[@"CFBundleURLTypes"] = CFBundleURLTypesM.copy;
	}

	[infoDictM writeToURL:infoPlistURL error:nil];
}

// 170: failed to create container for app bundle
// 171: a non trollstore app with the same identifier is already installled
// 172: no info.plist found in app
// 173: app is not signed and cannot be signed because ldid not installed or didn't work
// 174: 
int installApp(NSString* appPath, BOOL sign, BOOL force)
{
	NSLog(@"[installApp force = %d]", force);

	if(!infoDictionaryForAppPath(appPath)) return 172;

	NSString* appId = appIdForAppPath(appPath);
	if(!appId) return 176;

	applyPatchesToInfoDictionary(appPath);

	if(sign)
	{
		int signRet = signApp(appPath);
		if(signRet != 0) return signRet;
	}

	BOOL existed;
	NSError* mcmError;
	MCMAppContainer* appContainer = [objc_getClass("MCMAppContainer") containerWithIdentifier:appId createIfNecessary:YES existed:&existed error:&mcmError];
	if(!appContainer || mcmError)
	{
		NSLog(@"[installApp] failed to create app container for %@: %@", appId, mcmError);
		return 170;
	}

	if(existed)
	{
		NSLog(@"[installApp] got existing app container: %@", appContainer);
	}
	else
	{
		NSLog(@"[installApp] created app container: %@", appContainer);
	}

	// check if the bundle is empty
	BOOL isEmpty = YES;
	NSArray* bundleItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainer.url.path error:nil];
	for(NSString* bundleItem in bundleItems)
	{
		if([bundleItem.pathExtension isEqualToString:@"app"])
		{
			isEmpty = NO;
			break;
		}
	}

	NSLog(@"[installApp] container is empty? %d", isEmpty);

	// Make sure there isn't already an app store app installed with the same identifier
	NSURL* trollStoreMarkURL = [appContainer.url URLByAppendingPathComponent:@"_TrollStore"];
	if(existed && !isEmpty && ![trollStoreMarkURL checkResourceIsReachableAndReturnError:nil] && !force)
	{
		NSLog(@"[installApp] already installed and not a TrollStore app... bailing out");
		return 171;
	}

	// Mark app as TrollStore app
	BOOL marked = [[NSFileManager defaultManager] createFileAtPath:trollStoreMarkURL.path contents:[NSData data] attributes:nil];
	if(!marked)
	{
		NSLog(@"[installApp] failed to mark %@ as TrollStore app", appId);
		return 177;
	}

	// Apply correct permissions (First run, set everything to 644, owner 33)
	NSURL* fileURL;
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appPath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
	while(fileURL = [enumerator nextObject])
	{
		NSString* filePath = fileURL.path;
		chown(filePath.UTF8String, 33, 33);
		chmod(filePath.UTF8String, 0644);
		NSLog(@"[installApp] setting %@ to chown(33,33) chmod(0644)", filePath);
	}

	// Apply correct permissions (Second run, set executables and directories to 0755)
	enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appPath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
	while(fileURL = [enumerator nextObject])
	{
		NSString* filePath = fileURL.path;

		BOOL isDir;
		[[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&isDir];

		if([filePath.lastPathComponent isEqualToString:@"Info.plist"])
		{
			NSDictionary* infoDictionary = [NSDictionary dictionaryWithContentsOfFile:filePath];
			NSString* executable = infoDictionary[@"CFBundleExecutable"];
			if(executable && [executable isKindOfClass:[NSString class]])
			{
				NSString* executablePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:executable];
				chmod(executablePath.UTF8String, 0755);
				NSLog(@"[installApp] applied permissions for bundle executable %@", executablePath);
			}
			NSArray* tsRootBinaries = infoDictionary[@"TSRootBinaries"];
			if(tsRootBinaries && [tsRootBinaries isKindOfClass:[NSArray class]])
			{
				for(NSString* rootBinary in tsRootBinaries)
				{
					if([rootBinary isKindOfClass:[NSString class]])
					{
						NSString* rootBinaryPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:rootBinary];
						if([[NSFileManager defaultManager] fileExistsAtPath:rootBinaryPath])
						{
							chmod(rootBinaryPath.UTF8String, 0755);
							chown(rootBinaryPath.UTF8String, 0, 0);
							NSLog(@"[installApp] applied permissions for root binary %@", rootBinaryPath);
						}
					}
				}
			}
		}
		else if(!isDir && [filePath.pathExtension isEqualToString:@"dylib"])
		{
			chmod(filePath.UTF8String, 0755);
		}
		else if(isDir)
		{
			// apparently all dirs are writable by default
			chmod(filePath.UTF8String, 0755);
		}
	}

	// Set .app directory permissions too
	chmod(appPath.UTF8String, 0755);
	chown(appPath.UTF8String, 33, 33);

	// Wipe old version if needed
	if(existed)
	{
		NSLog(@"[installApp] found existing TrollStore app, cleaning directory");
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:appContainer.url includingPropertiesForKeys:nil options:0 errorHandler:nil];
		NSURL* fileURL;
		while(fileURL = [enumerator nextObject])
		{
			// do not under any circumstance delete this file as it makes iOS loose the app registration
			if([fileURL.lastPathComponent isEqualToString:@".com.apple.mobile_container_manager.metadata.plist"] || [fileURL.lastPathComponent isEqualToString:@"_TrollStore"])
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
	
	NSError* copyError;
	BOOL suc = [[NSFileManager defaultManager] copyItemAtPath:appPath toPath:newAppPath error:&copyError];
	if(suc)
	{
		NSLog(@"[installApp] App %@ installed, adding to icon cache now...", appId);
		registerPath((char*)newAppPath.UTF8String, 0);
		return 0;
	}
	else
	{
		NSLog(@"[installApp] Failed to copy app bundle for app %@, error: %@", appId, copyError);
		return 178;
	}
}

int uninstallApp(NSString* appPath, NSString* appId)
{
	LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:appId];
	MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer") containerWithIdentifier:appId createIfNecessary:NO existed:nil error:nil];
	NSString *containerPath = [appContainer url].path;
	if(containerPath)
	{
		NSLog(@"[uninstallApp] deleting %@", containerPath);
		// delete app container path
		[[NSFileManager defaultManager] removeItemAtPath:containerPath error:nil];
	}

	// delete group container paths
	[[appProxy groupContainerURLs] enumerateKeysAndObjectsUsingBlock:^(NSString* groupId, NSURL* groupURL, BOOL* stop)
	{
		// If another app still has this group, don't delete it
		NSArray<LSApplicationProxy*>* appsWithGroup = applicationsWithGroupId(groupId);
		if(appsWithGroup.count > 1)
		{
			NSLog(@"[uninstallApp] not deleting %@, appsWithGroup.count:%lu", groupURL, appsWithGroup.count);
			return;
		}

		NSLog(@"[uninstallApp] deleting %@", groupURL);
		[[NSFileManager defaultManager] removeItemAtURL:groupURL error:nil];
	}];

	// delete app plugin paths
	for(LSPlugInKitProxy* pluginProxy in appProxy.plugInKitPlugins)
	{
		NSURL* pluginURL = pluginProxy.dataContainerURL;
		if(pluginURL)
		{
			NSLog(@"[uninstallApp] deleting %@", pluginURL);
			[[NSFileManager defaultManager] removeItemAtURL:pluginURL error:nil];
		}
	}

	// unregister app
	registerPath((char*)appPath.UTF8String, 1);

	NSLog(@"[uninstallApp] deleting %@", [appPath stringByDeletingLastPathComponent]);
	// delete app
	BOOL deleteSuc = [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByDeletingLastPathComponent] error:nil];
	if(deleteSuc)
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

/*int detachApp(NSString* appId)
{
	NSString* appPath = appPathForAppId(appId);
	NSString* executablePath = appMainExecutablePathForAppPath(appPath);
	NSString* trollStoreMarkPath = [[appPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"_TrollStore"];

	// Not attached to TrollStore
	if(![[NSFileManager defaultManager] fileExistsAtPath:trollStoreMarkPath]) return 0;

	// Refuse to detach app if it's still signed with fake root cert
	SecStaticCodeRef codeRef = getStaticCodeRef(executablePath);
	if(codeRef != NULL)
	{
		if(codeCertChainContainsFakeAppStoreExtensions(codeRef))
		{
			CFRelease(codeRef);
			return 184;
		}
	}

	// Deleting TrollStore mark to detach app
	BOOL suc = [[NSFileManager defaultManager] removeItemAtPath:trollStoreMarkPath error:nil];
	return !suc;
}*/

int uninstallAppByPath(NSString* appPath)
{
	if(!appPath) return 1;
	NSString* appId = appIdForAppPath(appPath);
	if(!appId) return 1;
	return uninstallApp(appPath, appId);
}

int uninstallAppById(NSString* appId)
{
	if(!appId) return 1;
	NSString* appPath = appPathForAppId(appId);
	if(!appPath) return 1;
	return uninstallApp(appPath, appId);
}

// 166: IPA does not exist or is not accessible
// 167: IPA does not appear to contain an app

int installIpa(NSString* ipaPath, BOOL force)
{
	if(![[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) return 166;

	BOOL suc = NO;
	NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	
	suc = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:NO attributes:nil error:nil];
	if(!suc) return 1;

	extract(ipaPath, tmpPath);

	NSString* tmpPayloadPath = [tmpPath stringByAppendingPathComponent:@"Payload"];
	
	NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPayloadPath error:nil];
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
	
	int ret = installApp(tmpAppPath, YES, force);
	
	[[NSFileManager defaultManager] removeItemAtPath:tmpAppPath error:nil];

	return ret;
}

void uninstallAllApps(void)
{
	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		uninstallAppById(appIdForAppPath(appPath));
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

	return installApp(tmpTrollStore, NO, YES);;
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

		NSString* cmd = [NSString stringWithUTF8String:argv[1]];
		if([cmd isEqualToString:@"install"])
		{
			NSLog(@"argc = %d", argc);
			BOOL force = NO;
			if(argc <= 2) return -3;
			if(argc > 3)
			{
				NSLog(@"argv3 = %s", argv[3]);
				if(!strcmp(argv[3], "force"))
				{
					force = YES;
				}
			}
			NSString* ipaPath = [NSString stringWithUTF8String:argv[2]];
			ret = installIpa(ipaPath, force);
		} else if([cmd isEqualToString:@"uninstall"])
		{
			if(argc <= 2) return -3;
			NSString* appId = [NSString stringWithUTF8String:argv[2]];
			ret = uninstallAppById(appId);
		} /*else if([cmd isEqualToString:@"detach"])
		{
			if(argc <= 2) return -3;
			NSString* appId = [NSString stringWithUTF8String:argv[2]];
			ret = detachApp(appId);
		} */else if([cmd isEqualToString:@"uninstall-path"])
		{
			if(argc <= 2) return -3;
			NSString* appPath = [NSString stringWithUTF8String:argv[2]];
			ret = uninstallAppByPath(appPath);
		}else if([cmd isEqualToString:@"install-trollstore"])
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

		NSLog(@"returning %d", ret);

		return ret;
	}
}
