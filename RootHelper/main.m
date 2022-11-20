#import <stdio.h>
#import "unarchive.h"
@import Foundation;
#import "uicache.h"
#import <sys/stat.h>
#import <dlfcn.h>
#import <spawn.h>
#import <objc/runtime.h>
#import <TSUtil.h>
#import <sys/utsname.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

#import <SpringBoardServices/SpringBoardServices.h>
#import <Security/Security.h>

#ifdef EMBEDDED_ROOT_HELPER
#define MAIN_NAME rootHelperMain
#else
#define MAIN_NAME main
#endif

void cleanRestrictions(void);

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
		for(NSString* claimedURLScheme in proxy.claimedURLSchemes)
		{
			if([claimedURLScheme isKindOfClass:NSString.class])
			{
				[systemURLSchemes addObject:claimedURLScheme.lowercaseString];
			}
		}
	}

	return systemURLSchemes.copy;
}

NSSet<NSString*>* immutableAppBundleIdentifiers(void)
{
	NSMutableSet* systemAppIdentifiers = [NSMutableSet new];

	LSEnumerator* enumerator = [LSEnumerator enumeratorForApplicationProxiesWithOptions:0];
	LSApplicationProxy* appProxy;
	while(appProxy = [enumerator nextObject])
	{
		if(appProxy.installed)
		{
			if(![appProxy.bundleURL.path hasPrefix:@"/private/var/containers"])
			{
				[systemAppIdentifiers addObject:appProxy.bundleIdentifier.lowercaseString];
			}
		}
	}

	return systemAppIdentifiers.copy;
}

NSDictionary* infoDictionaryForAppPath(NSString* appPath)
{
	if(!appPath) return nil;
	NSString* infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	return [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
}

NSString* appIdForAppPath(NSString* appPath)
{
	if(!appPath) return nil;
	return infoDictionaryForAppPath(appPath)[@"CFBundleIdentifier"];
}

NSString* appMainExecutablePathForAppPath(NSString* appPath)
{
	if(!appPath) return nil;
	return [appPath stringByAppendingPathComponent:infoDictionaryForAppPath(appPath)[@"CFBundleExecutable"]];
}

NSString* appPathForAppId(NSString* appId)
{
	if(!appId) return nil;
	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		if([appIdForAppPath(appPath) isEqualToString:appId])
		{
			return appPath;
		}
	}
	return nil;
}

BOOL isMachoFile(NSString* filePath)
{
	FILE* file = fopen(filePath.fileSystemRepresentation, "r");
	if(!file) return NO;

	fseek(file, 0, SEEK_SET);
	uint32_t magic;
	fread(&magic, sizeof(uint32_t), 1, file);
	fclose(file);

	return magic == FAT_MAGIC || magic == FAT_CIGAM || magic == MH_MAGIC_64 || magic == MH_CIGAM_64;
}

void fixPermissionsOfAppBundle(NSString* appBundlePath)
{
	// Apply correct permissions (First run, set everything to 644, owner 33)
	NSURL* fileURL;
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appBundlePath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
	while(fileURL = [enumerator nextObject])
	{
		NSString* filePath = fileURL.path;
		chown(filePath.fileSystemRepresentation, 33, 33);
		chmod(filePath.fileSystemRepresentation, 0644);
	}

	// Apply correct permissions (Second run, set executables and directories to 0755)
	enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appBundlePath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
	while(fileURL = [enumerator nextObject])
	{
		NSString* filePath = fileURL.path;

		BOOL isDir;
		[[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&isDir];

		if(isDir || isMachoFile(filePath))
		{
			chmod(filePath.fileSystemRepresentation, 0755);
		}
	}
}

NSArray* TSURLScheme(void)
{
	return @[
		@{
			@"CFBundleURLName" : @"com.apple.Magnifier",
			@"CFBundleURLSchemes" : @[
				@"apple-magnifier"
			]
		}
	];
}

BOOL getTSURLSchemeState(NSString* customAppPath)
{
	NSString* pathToUse = customAppPath ?: trollStoreAppPath();

	NSDictionary* trollStoreInfoDict = infoDictionaryForAppPath(pathToUse);
	return (BOOL)trollStoreInfoDict[@"CFBundleURLTypes"];
}

void setTSURLSchemeState(BOOL newState, NSString* customAppPath)
{
	NSString* tsAppPath = trollStoreAppPath();
	NSString* pathToUse = customAppPath ?: tsAppPath;
	if(newState != getTSURLSchemeState(pathToUse))
	{
		NSDictionary* trollStoreInfoDict = infoDictionaryForAppPath(pathToUse);
		NSMutableDictionary* trollStoreInfoDictM = trollStoreInfoDict.mutableCopy;
		if(newState)
		{
			trollStoreInfoDictM[@"CFBundleURLTypes"] = TSURLScheme();
		}
		else
		{
			[trollStoreInfoDictM removeObjectForKey:@"CFBundleURLTypes"];
		}
		NSString* outPath = [pathToUse stringByAppendingPathComponent:@"Info.plist"];
		[trollStoreInfoDictM.copy writeToURL:[NSURL fileURLWithPath:outPath] error:nil];
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

	chmod(ldidPath.fileSystemRepresentation, 0755);
	chown(ldidPath.fileSystemRepresentation, 0, 0);
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
	int spawnError = posix_spawn(&task_pid, [ldidPath fileSystemRepresentation], &action, NULL, (char* const*)argsC, NULL);
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
		// Work around an ldid bug where it doesn't keep entitlements on stray binaries
		NSMutableDictionary* storedEntitlements = [NSMutableDictionary new];
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:appPath] includingPropertiesForKeys:nil options:0 errorHandler:nil];
		NSURL* fileURL;
		while(fileURL = [enumerator nextObject])
		{
			NSString* filePath = fileURL.path;
			if(isMachoFile(filePath))
			{
				storedEntitlements[filePath] = dumpEntitlementsFromBinaryAtPath(filePath);
			}
		}

		// app has entitlements, keep them
		ldidRet = runLdid(@[@"-s", certArg, appPath], nil, &errorOutput);

		[storedEntitlements enumerateKeysAndObjectsUsingBlock:^(NSString* binaryPath, NSDictionary* entitlements, BOOL* stop)
		{
			NSDictionary* newEntitlements = dumpEntitlementsFromBinaryAtPath(binaryPath);
			if(!newEntitlements || ![newEntitlements isEqualToDictionary:entitlements])
			{
				NSString* tmpEntitlementPlistPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ent.xml"];
				[entitlements writeToURL:[NSURL fileURLWithPath:tmpEntitlementPlistPath] error:nil];
				NSString* tmpEntitlementArg = [@"-S" stringByAppendingString:tmpEntitlementPlistPath];
				runLdid(@[tmpEntitlementArg, certArg, binaryPath], nil, nil);
				[[NSFileManager defaultManager] removeItemAtPath:tmpEntitlementPlistPath error:nil];
			}
		}];
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
				for(NSString* existingURLScheme in [URLSchemesSet copy])
				{
					if(![existingURLScheme isKindOfClass:[NSString class]])
					{
						[URLSchemesSet removeObject:existingURLScheme];
						continue;
					}

					if([appleSchemes containsObject:existingURLScheme.lowercaseString])
					{
						[URLSchemesSet removeObject:existingURLScheme];
					}
				}
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
int installApp(NSString* appPackagePath, BOOL sign, BOOL force, BOOL isTSUpdate)
{
	NSLog(@"[installApp force = %d]", force);

	NSString* appPayloadPath = [appPackagePath stringByAppendingPathComponent:@"Payload"];
	
	NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appPayloadPath error:nil];
	if(!items) return 167;
	
	NSString* appBundlePath;
	for(NSString* item in items)
	{
		if([item.pathExtension isEqualToString:@"app"])
		{
			appBundlePath = [appPayloadPath stringByAppendingPathComponent:item];
			break;
		}
	}
	if(!appBundlePath) return 167;

	NSString* appId = appIdForAppPath(appBundlePath);
	if(!appId) return 176;

	if(([appId.lowercaseString isEqualToString:@"com.opa334.trollstore"] && !isTSUpdate) || [immutableAppBundleIdentifiers() containsObject:appId.lowercaseString])
	{
		return 179;
	}

	if(!infoDictionaryForAppPath(appBundlePath)) return 172;

	if(!isTSUpdate)
	{
		applyPatchesToInfoDictionary(appBundlePath);
	}

	if(sign)
	{
		int signRet = signApp(appBundlePath);
		if(signRet != 0) return signRet;
	}

	LSApplicationProxy* existingAppProxy = [LSApplicationProxy applicationProxyForIdentifier:appId];
	if(existingAppProxy.installed)
	{
		// App update
		// Replace existing bundle with new version

		// Check if the existing app bundle is empty
		BOOL appBundleExists = existingAppProxy.bundleURL && [existingAppProxy.bundleURL checkResourceIsReachableAndReturnError:nil];

		// LSBundleProxy also has a bundleContainerURL property, but unforunately it is unreliable and just nil most of the time
		NSURL* bundleContainerURL = existingAppProxy.bundleURL.URLByDeletingLastPathComponent;

		// Make sure the installed app is a TrollStore app or the container is empty (or the force flag is set)
		NSURL* trollStoreMarkURL = [bundleContainerURL URLByAppendingPathComponent:@"_TrollStore"];
		if(appBundleExists && ![trollStoreMarkURL checkResourceIsReachableAndReturnError:nil] && !force)
		{
			NSLog(@"[installApp] already installed and not a TrollStore app... bailing out");
			return 171;
		}

		// Terminate app if it's still running
		if(!isTSUpdate)
		{
			BKSTerminateApplicationForReasonAndReportWithDescription(appId, 5, false, @"TrollStore - App updated");
		}

		NSLog(@"[installApp] replacing existing app with new version");

		// Delete existing .app directory if it exists
		if(appBundleExists)
		{
			[[NSFileManager defaultManager] removeItemAtURL:existingAppProxy.bundleURL error:nil];
		}

		// Install new version into existing app bundle
		NSError* copyError;
		BOOL suc = [[NSFileManager defaultManager] copyItemAtPath:appBundlePath toPath:[bundleContainerURL.path stringByAppendingPathComponent:appBundlePath.lastPathComponent] error:&copyError];
		if(!suc)
		{
			NSLog(@"[installApp] Error copying new version during update: %@", copyError);
			return 178;
		}
	}
	else
	{
		// Initial app install
		// Do initial placeholder installation using LSApplicationWorkspace

		NSError* installError;
		BOOL suc = NO;
		@try
		{
			suc = [[LSApplicationWorkspace defaultWorkspace] installApplication:[NSURL fileURLWithPath:appPackagePath] withOptions:@{
				LSInstallTypeKey : @1,
				@"PackageType" : @"Placeholder"
			} error:&installError];
		}
		@catch(NSException* e)
		{
			NSLog(@"[installApp] encountered expection %@ while trying to do placeholder install", e);
			suc = NO;
		}
		
		if(!suc)
		{
			NSLog(@"[installApp] encountered error %@ while trying to do placeholder install", installError);
			return 180;
		}

		// Get newly installed proxy
		existingAppProxy = [LSApplicationProxy applicationProxyForIdentifier:appId];

		// Mark app as TrollStore app
		NSURL* bundleContainerURL = existingAppProxy.bundleURL.URLByDeletingLastPathComponent;
		NSURL* trollStoreMarkURL = [bundleContainerURL URLByAppendingPathComponent:@"_TrollStore"];
		BOOL marked = [[NSFileManager defaultManager] createFileAtPath:trollStoreMarkURL.path contents:[NSData data] attributes:nil];
		if(!marked)
		{
			NSLog(@"[installApp] failed to mark %@ as TrollStore app", appId);
			return 177;
		}
	}

	// At this point the (new version of the) app is installed but still needs to be registered
	// Also permissions need to be fixed
	fixPermissionsOfAppBundle(existingAppProxy.bundleURL.path);
	registerPath((char*)existingAppProxy.bundleURL.path.fileSystemRepresentation, 0, YES);
}

int uninstallApp(NSString* appPath, NSString* appId)
{
	BOOL deleteSuc = NO;
	if(!appId && appPath)
	{
		// Special case, something is wrong about this app
		// Most likely the Info.plist is missing
		// (Hopefully this never happens)
		deleteSuc = [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByDeletingLastPathComponent] error:nil];
		registerPath((char*)appPath.fileSystemRepresentation, 1, YES);
		return 0;
	}

	if(appId)
	{
		deleteSuc = [[LSApplicationWorkspace defaultWorkspace] uninstallApplication:appId withOptions:nil];
	}

	if(deleteSuc)
	{
		cleanRestrictions();
		return 0;
	}
	else
	{
		return 1;
	}
}

int uninstallAppByPath(NSString* appPath)
{
	if(!appPath) return 1;

	NSString* standardizedAppPath = appPath.stringByStandardizingPath;

	if(![standardizedAppPath hasPrefix:@"/var/containers/Bundle/Application/"] && standardizedAppPath.pathComponents.count == 5)
	{
		return 1;
	}

	NSString* appId = appIdForAppPath(standardizedAppPath);
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
	cleanRestrictions();

	if(![[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) return 166;

	BOOL suc = NO;
	NSString* tmpPackagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	
	suc = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPackagePath withIntermediateDirectories:NO attributes:nil error:nil];
	if(!suc) return 1;

	int extractRet = extract(ipaPath, tmpPackagePath);
	if(extractRet != 0)
	{
		[[NSFileManager defaultManager] removeItemAtPath:tmpPackagePath error:nil];
		return 168;
	}

	int ret = installApp(tmpPackagePath, YES, force, NO);
	
	[[NSFileManager defaultManager] removeItemAtPath:tmpPackagePath error:nil];

	return ret;
}

void uninstallAllApps(void)
{
	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		uninstallAppById(appIdForAppPath(appPath));
	}
}

int uninstallTrollStore(BOOL unregister)
{
	NSString* trollStore = trollStorePath();
	if(![[NSFileManager defaultManager] fileExistsAtPath:trollStore]) return NO;

	if(unregister)
	{
		registerPath((char*)trollStoreAppPath().fileSystemRepresentation, 1, YES);
	}

	return [[NSFileManager defaultManager] removeItemAtPath:trollStore error:nil];
}

int installTrollStore(NSString* pathToTar)
{
	_CFPreferencesSetValueWithContainerType _CFPreferencesSetValueWithContainer = (_CFPreferencesSetValueWithContainerType)dlsym(RTLD_DEFAULT, "_CFPreferencesSetValueWithContainer");
	_CFPreferencesSynchronizeWithContainerType _CFPreferencesSynchronizeWithContainer = (_CFPreferencesSynchronizeWithContainerType)dlsym(RTLD_DEFAULT, "_CFPreferencesSynchronizeWithContainer");
	_CFPreferencesSetValueWithContainer(CFSTR("SBShowNonDefaultSystemApps"), kCFBooleanTrue, CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
	_CFPreferencesSynchronizeWithContainer(CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);

	if(![[NSFileManager defaultManager] fileExistsAtPath:pathToTar]) return 1;
	if(![pathToTar.pathExtension isEqualToString:@"tar"]) return 1;

	NSString* tmpPackagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	NSString* tmpPayloadPath = [tmpPackagePath stringByAppendingPathComponent:@"Payload"];
	BOOL suc = [[NSFileManager defaultManager] createDirectoryAtPath:tmpPayloadPath withIntermediateDirectories:YES attributes:nil error:nil];
	if(!suc) return 1;

	int extractRet = extract(pathToTar, tmpPayloadPath);
	if(extractRet != 0)
	{
		[[NSFileManager defaultManager] removeItemAtPath:tmpPackagePath error:nil];
		return 169;
	}

	NSString* tmpTrollStorePath = [tmpPayloadPath stringByAppendingPathComponent:@"TrollStore.app"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:tmpTrollStorePath]) return 1;

	// Save existing ldid installation if it exists
	NSString* existingLdidPath = [trollStoreAppPath() stringByAppendingPathComponent:@"ldid"];
	if([[NSFileManager defaultManager] fileExistsAtPath:existingLdidPath])
	{
		NSString* tmpLdidPath = [tmpTrollStorePath stringByAppendingPathComponent:@"ldid"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpLdidPath])
		{
			[[NSFileManager defaultManager] copyItemAtPath:existingLdidPath toPath:tmpLdidPath error:nil];
		}
	}

	// Merge existing URL scheme settings value
	if(!getTSURLSchemeState(nil))
	{
		setTSURLSchemeState(NO, tmpTrollStorePath);
	}

	// Update system app persistence helper if used
	LSApplicationProxy* persistenceHelperApp = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_SYSTEM);
	if(persistenceHelperApp)
	{
		NSString* trollStorePersistenceHelper = [tmpTrollStorePath stringByAppendingPathComponent:@"PersistenceHelper"];
		NSString* trollStoreRootHelper = [tmpTrollStorePath stringByAppendingPathComponent:@"trollstorehelper"];
		_installPersistenceHelper(persistenceHelperApp, trollStorePersistenceHelper, trollStoreRootHelper);
	}

	int ret = installApp(tmpPackagePath, NO, YES, YES);
	NSLog(@"[installTrollStore] installApp => %d", ret);
	[[NSFileManager defaultManager] removeItemAtPath:tmpPackagePath error:nil];
	return ret;
}

void refreshAppRegistrations()
{
	//registerPath((char*)trollStoreAppPath().fileSystemRepresentation, 1, YES);
	registerPath((char*)trollStoreAppPath().fileSystemRepresentation, 0, YES);

	for(NSString* appPath in trollStoreInstalledAppBundlePaths())
	{
		//registerPath((char*)appPath.fileSystemRepresentation, 1, YES);
		registerPath((char*)appPath.fileSystemRepresentation, 0, YES);
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
	NSString* rootHelperPath = [bundlePath stringByAppendingPathComponent:@"trollstorehelper"];

	// remove existing persistence helper binary if exists
	if([[NSFileManager defaultManager] fileExistsAtPath:markPath] && [[NSFileManager defaultManager] fileExistsAtPath:executablePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:executablePath error:nil];
	}

	// remove existing root helper binary if exists
	if([[NSFileManager defaultManager] fileExistsAtPath:rootHelperPath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:rootHelperPath error:nil];
	}

	// install new persistence helper binary
	if(![[NSFileManager defaultManager] copyItemAtPath:sourcePersistenceHelper toPath:executablePath error:nil])
	{
		return NO;
	}

	chmod(executablePath.fileSystemRepresentation, 0755);
	chown(executablePath.fileSystemRepresentation, 33, 33);

	NSError* error;
	if(![[NSFileManager defaultManager] copyItemAtPath:sourceRootHelper toPath:rootHelperPath error:&error])
	{
		NSLog(@"error copying root helper: %@", error);
	}

	chmod(rootHelperPath.fileSystemRepresentation, 0755);
	chown(rootHelperPath.fileSystemRepresentation, 0, 0);

	// mark system app as persistence helper
	if(![[NSFileManager defaultManager] fileExistsAtPath:markPath])
	{
		[[NSFileManager defaultManager] createFileAtPath:markPath contents:[NSData data] attributes:nil];
	}

	return YES;
}

void installPersistenceHelper(NSString* systemAppId)
{
	if(findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_ALL)) return;

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

void unregisterUserPersistenceHelper()
{
	LSApplicationProxy* userAppProxy = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_USER);
	if(userAppProxy)
	{
		NSString* markPath = [userAppProxy.bundleURL.path stringByAppendingPathComponent:@".TrollStorePersistenceHelper"];
		[[NSFileManager defaultManager] removeItemAtPath:markPath error:nil];
	}
}

void uninstallPersistenceHelper(void)
{
	LSApplicationProxy* systemAppProxy = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_SYSTEM);
	if(systemAppProxy)
	{
		NSString* executablePath = systemAppProxy.canonicalExecutablePath;
		NSString* bundlePath = systemAppProxy.bundleURL.path;
		NSString* backupPath = [bundlePath stringByAppendingPathComponent:[[executablePath lastPathComponent] stringByAppendingString:@"_TROLLSTORE_BACKUP"]];
		if(![[NSFileManager defaultManager] fileExistsAtPath:backupPath]) return;

		NSString* helperPath = [bundlePath stringByAppendingPathComponent:@"trollstorehelper"];
		NSString* markPath = [bundlePath stringByAppendingPathComponent:@".TrollStorePersistenceHelper"];

		[[NSFileManager defaultManager] removeItemAtPath:executablePath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:markPath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:helperPath error:nil];

		[[NSFileManager defaultManager] moveItemAtPath:backupPath toPath:executablePath error:nil];

		BKSTerminateApplicationForReasonAndReportWithDescription(systemAppProxy.bundleIdentifier, 5, false, @"TrollStore - Reload persistence helper");
	}

	LSApplicationProxy* userAppProxy = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_USER);
	if(userAppProxy)
	{
		unregisterUserPersistenceHelper();
	}
}

void registerUserPersistenceHelper(NSString* userAppId)
{
	if(findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_ALL)) return;

	LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:userAppId];
	if(!appProxy || ![appProxy.bundleType isEqualToString:@"User"]) return;

	NSString* markPath = [appProxy.bundleURL.path stringByAppendingPathComponent:@".TrollStorePersistenceHelper"];
	[[NSFileManager defaultManager] createFileAtPath:markPath contents:[NSData data] attributes:nil];
}

// Apparently there is some odd behaviour where TrollStore installed apps sometimes get restricted
// This works around that issue at least and is triggered when rebuilding icon cache
void cleanRestrictions(void)
{
	NSString* clientTruthPath = @"/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/ClientTruth.plist";
	NSURL* clientTruthURL = [NSURL fileURLWithPath:clientTruthPath];
	NSDictionary* clientTruthDictionary = [NSDictionary dictionaryWithContentsOfURL:clientTruthURL];

	if(!clientTruthDictionary) return;

	NSArray* valuesArr;

	NSDictionary* lsdAppRemoval = clientTruthDictionary[@"com.apple.lsd.appremoval"];
	if(lsdAppRemoval && [lsdAppRemoval isKindOfClass:NSDictionary.class])
	{
		NSDictionary* clientRestrictions = lsdAppRemoval[@"clientRestrictions"];
		if(clientRestrictions && [clientRestrictions isKindOfClass:NSDictionary.class])
		{
			NSDictionary* unionDict = clientRestrictions[@"union"];
			if(unionDict && [unionDict isKindOfClass:NSDictionary.class])
			{
				NSDictionary* removedSystemAppBundleIDs = unionDict[@"removedSystemAppBundleIDs"];
				if(removedSystemAppBundleIDs && [removedSystemAppBundleIDs isKindOfClass:NSDictionary.class])
				{
					valuesArr = removedSystemAppBundleIDs[@"values"];
				}
			}
		}
	}

	if(!valuesArr || !valuesArr.count) return;

	NSMutableArray* valuesArrM = valuesArr.mutableCopy;
	__block BOOL changed = NO;

	[valuesArrM enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString* value, NSUInteger idx, BOOL *stop)
	{
		if(![value hasPrefix:@"com.apple."])
		{
			[valuesArrM removeObjectAtIndex:idx];
			changed = YES;
		}
	}];

	if(!changed) return;

	NSMutableDictionary* clientTruthDictionaryM = (__bridge_transfer NSMutableDictionary*)CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)clientTruthDictionary, kCFPropertyListMutableContainersAndLeaves);
	
	clientTruthDictionaryM[@"com.apple.lsd.appremoval"][@"clientRestrictions"][@"union"][@"removedSystemAppBundleIDs"][@"values"] = valuesArrM;

	[clientTruthDictionaryM writeToURL:clientTruthURL error:nil];

	killall(@"profiled", NO); // profiled needs to restart for the changes to apply
}

int MAIN_NAME(int argc, char *argv[], char *envp[])
{
	@autoreleasepool {
		if(argc <= 1) return -1;

		NSLog(@"trollstore helper go, uid: %d, gid: %d", getuid(), getgid());

		int ret = 0;

		NSString* cmd = [NSString stringWithUTF8String:argv[1]];
		if([cmd isEqualToString:@"install"])
		{
			BOOL force = NO;
			if(argc <= 2) return -3;
			if(argc > 3)
			{
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
		} else if([cmd isEqualToString:@"uninstall-path"])
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
		} else if([cmd isEqualToString:@"uninstall-trollstore-preserve-apps"])
		{
			uninstallTrollStore(YES);
		}else if([cmd isEqualToString:@"install-ldid"])
		{
			if(argc <= 2) return -3;
			NSString* ldidPath = [NSString stringWithUTF8String:argv[2]];
			installLdid(ldidPath);
		} else if([cmd isEqualToString:@"refresh"])
		{
			refreshAppRegistrations();
		} else if([cmd isEqualToString:@"refresh-all"])
		{
			cleanRestrictions();
			[[LSApplicationWorkspace defaultWorkspace] _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:YES];
			refreshAppRegistrations();
			killall(@"backboardd", YES);
		} else if([cmd isEqualToString:@"install-persistence-helper"])
		{
			if(argc <= 2) return -3;
			NSString* systemAppId = [NSString stringWithUTF8String:argv[2]];
			installPersistenceHelper(systemAppId);
		} else if([cmd isEqualToString:@"uninstall-persistence-helper"])
		{
			uninstallPersistenceHelper();
		} else if([cmd isEqualToString:@"register-user-persistence-helper"])
		{
			if(argc <= 2) return -3;
			NSString* userAppId = [NSString stringWithUTF8String:argv[2]];
			registerUserPersistenceHelper(userAppId);
		} else if([cmd isEqualToString:@"modify-registration"])
		{
			if(argc <= 3) return -3;
			NSString* appPath = [NSString stringWithUTF8String:argv[2]];
			NSString* newRegistration = [NSString stringWithUTF8String:argv[3]];

			NSString* trollStoreMark = [[appPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"_TrollStore"];
			if([[NSFileManager defaultManager] fileExistsAtPath:trollStoreMark])
			{
				registerPath((char*)appPath.fileSystemRepresentation, 0, [newRegistration isEqualToString:@"System"]);
			}
		} else if([cmd isEqualToString:@"url-scheme"])
		{
			if(argc <= 2) return -3;
			NSString* modifyArg = [NSString stringWithUTF8String:argv[2]];
			BOOL newState = [modifyArg isEqualToString:@"enable"];
			if(newState == YES || [modifyArg isEqualToString:@"disable"])
			{
				setTSURLSchemeState(newState, nil);
			}
		}

		NSLog(@"returning %d", ret);

		return ret;
	}
}
