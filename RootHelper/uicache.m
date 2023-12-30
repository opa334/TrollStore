@import Foundation;
@import CoreServices;
#import "CoreServices.h"
#import <objc/runtime.h>
#import "dlfcn.h"
#import <TSUtil.h>
#import <version.h>

// uicache on steroids

extern NSSet<NSString*>* immutableAppBundleIdentifiers(void);
extern NSDictionary* dumpEntitlementsFromBinaryAtPath(NSString* binaryPath);

NSDictionary *constructGroupsContainersForEntitlements(NSDictionary *entitlements, BOOL systemGroups) {
	if (!entitlements) return nil;

	NSString *entitlementForGroups;
	Class mcmClass;
	if (systemGroups) {
		entitlementForGroups = @"com.apple.security.system-groups";
		mcmClass = [MCMSystemDataContainer class];
	}
	else {
		entitlementForGroups = @"com.apple.security.application-groups";
		mcmClass = [MCMSharedDataContainer class];
	}

	NSArray *groupIDs = entitlements[entitlementForGroups];
	if (groupIDs && [groupIDs isKindOfClass:[NSArray class]]) {
		NSMutableDictionary *groupContainers = [NSMutableDictionary new];

		for (NSString *groupID in groupIDs) {
			MCMContainer *container = [mcmClass containerWithIdentifier:groupID createIfNecessary:YES existed:nil error:nil];
			if (container.url) {
				groupContainers[groupID] = container.url.path;
			}
		}

		return groupContainers.copy;
	}

	return nil;
}

BOOL constructContainerizationForEntitlements(NSDictionary *entitlements, NSString **customContainerOut) {
	NSNumber *noContainer = entitlements[@"com.apple.private.security.no-container"];
	if (noContainer && [noContainer isKindOfClass:[NSNumber class]]) {
		if (noContainer.boolValue) {
			return NO;
		}
	}

	NSObject *containerRequired = entitlements[@"com.apple.private.security.container-required"];
	if (containerRequired && [containerRequired isKindOfClass:[NSNumber class]]) {
		if (!((NSNumber *)containerRequired).boolValue) {
			return NO;
		}
	}
	else if (containerRequired && [containerRequired isKindOfClass:[NSString class]]) {
		*customContainerOut = (NSString *)containerRequired;
	}

	return YES;
}

NSString *constructTeamIdentifierForEntitlements(NSDictionary *entitlements) {
	NSString *teamIdentifier = entitlements[@"com.apple.developer.team-identifier"];
	if (teamIdentifier && [teamIdentifier isKindOfClass:[NSString class]]) {
		return teamIdentifier;
	}
	return nil;
}

NSDictionary *constructEnvironmentVariablesForContainerPath(NSString *containerPath, BOOL isContainerized) {
	NSString *homeDir = isContainerized ? containerPath : @"/var/mobile";
	NSString *tmpDir = isContainerized ? [containerPath stringByAppendingPathComponent:@"tmp"] : @"/var/tmp";
	return @{
		@"CFFIXED_USER_HOME" : homeDir,
		@"HOME" : homeDir,
		@"TMPDIR" : tmpDir
	};
}

bool registerPath(NSString *path, BOOL unregister, BOOL forceSystem) {
	if (!path) return false;

	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	if (unregister && ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:path];
		if (app.bundleURL) {
			path = [app bundleURL].path;
		}
	}

	path = path.stringByResolvingSymlinksInPath.stringByStandardizingPath;

	NSDictionary *appInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
	NSString *appBundleID = [appInfoPlist objectForKey:@"CFBundleIdentifier"];

	if([immutableAppBundleIdentifiers() containsObject:appBundleID.lowercaseString]) return false;

	if (appBundleID && !unregister) {
		NSString *appExecutablePath = [path stringByAppendingPathComponent:appInfoPlist[@"CFBundleExecutable"]];
		NSDictionary *entitlements = dumpEntitlementsFromBinaryAtPath(appExecutablePath);

		NSString *appDataContainerID = appBundleID;
		BOOL appContainerized = constructContainerizationForEntitlements(entitlements, &appDataContainerID);

		MCMContainer *appDataContainer = [NSClassFromString(@"MCMAppDataContainer") containerWithIdentifier:appDataContainerID createIfNecessary:YES existed:nil error:nil];
		NSString *containerPath = [appDataContainer url].path;

		BOOL isRemovableSystemApp = [[NSFileManager defaultManager] fileExistsAtPath:[@"/System/Library/AppSignatures" stringByAppendingPathComponent:appBundleID]];
		BOOL registerAsUser = [path hasPrefix:@"/var/containers"] && !isRemovableSystemApp && !forceSystem;

		NSMutableDictionary *dictToRegister = [NSMutableDictionary dictionary];

		// Add entitlements

		if (entitlements) {
			dictToRegister[@"Entitlements"] = entitlements;
		}

		// Misc
	
		dictToRegister[@"ApplicationType"] = registerAsUser ? @"User" : @"System";
		dictToRegister[@"CFBundleIdentifier"] = appBundleID;
		dictToRegister[@"CodeInfoIdentifier"] = appBundleID;
		dictToRegister[@"CompatibilityState"] = @0;
		dictToRegister[@"IsContainerized"] = @(appContainerized);
		if (containerPath) {
			dictToRegister[@"Container"] = containerPath;
			dictToRegister[@"EnvironmentVariables"] = constructEnvironmentVariablesForContainerPath(containerPath, appContainerized);
		}
		dictToRegister[@"IsDeletable"] = @(![appBundleID isEqualToString:@"com.opa334.TrollStore"] && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0);
		dictToRegister[@"Path"] = path;
		
		dictToRegister[@"SignerOrganization"] = @"Apple Inc.";
		dictToRegister[@"SignatureVersion"] = @132352;
		dictToRegister[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";
		dictToRegister[@"IsAdHocSigned"] = @YES;
		dictToRegister[@"LSInstallType"] = @1;
		dictToRegister[@"HasMIDBasedSINF"] = @0;
		dictToRegister[@"MissingSINF"] = @0;
		dictToRegister[@"FamilyID"] = @0;
		dictToRegister[@"IsOnDemandInstallCapable"] = @0;

		NSString *teamIdentifier = constructTeamIdentifierForEntitlements(entitlements);
		if (teamIdentifier) dictToRegister[@"TeamIdentifier"] = teamIdentifier;

		// Add group containers

		NSDictionary *appGroupContainers = constructGroupsContainersForEntitlements(entitlements, NO);
		NSDictionary *systemGroupContainers = constructGroupsContainersForEntitlements(entitlements, YES);
		NSMutableDictionary *groupContainers = [NSMutableDictionary new];
		[groupContainers addEntriesFromDictionary:appGroupContainers];
		[groupContainers addEntriesFromDictionary:systemGroupContainers];
		if (groupContainers.count) {
			if (appGroupContainers.count) {
				dictToRegister[@"HasAppGroupContainers"] = @YES;
			}
			if (systemGroupContainers.count) {
				dictToRegister[@"HasSystemGroupContainers"] = @YES;
			}
			dictToRegister[@"GroupContainers"] = groupContainers.copy;
		}

		// Add plugins

		NSString *pluginsPath = [path stringByAppendingPathComponent:@"PlugIns"];
		NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];

		NSMutableDictionary *bundlePlugins = [NSMutableDictionary dictionary];
		for (NSString *pluginName in plugins) {
			NSString *pluginPath = [pluginsPath stringByAppendingPathComponent:pluginName];

			NSDictionary *pluginInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[pluginPath stringByAppendingPathComponent:@"Info.plist"]];
			NSString *pluginBundleID = [pluginInfoPlist objectForKey:@"CFBundleIdentifier"];

			if (!pluginBundleID) continue;
			NSString *pluginExecutablePath = [pluginPath stringByAppendingPathComponent:pluginInfoPlist[@"CFBundleExecutable"]];
			NSDictionary *pluginEntitlements = dumpEntitlementsFromBinaryAtPath(pluginExecutablePath);
			NSString *pluginDataContainerID = pluginBundleID;
			BOOL pluginContainerized = constructContainerizationForEntitlements(pluginEntitlements, &pluginDataContainerID);

			MCMContainer *pluginContainer = [NSClassFromString(@"MCMPluginKitPluginDataContainer") containerWithIdentifier:pluginDataContainerID createIfNecessary:YES existed:nil error:nil];
			NSString *pluginContainerPath = [pluginContainer url].path;

			NSMutableDictionary *pluginDict = [NSMutableDictionary dictionary];

			// Add entitlements
			if (pluginEntitlements) {
				pluginDict[@"Entitlements"] = pluginEntitlements;
			}

			// Misc

			pluginDict[@"ApplicationType"] = @"PluginKitPlugin";
			pluginDict[@"CFBundleIdentifier"] = pluginBundleID;
			pluginDict[@"CodeInfoIdentifier"] = pluginBundleID;
			pluginDict[@"CompatibilityState"] = @0;
			
			pluginDict[@"IsContainerized"] = @(pluginContainerized);
			if (pluginContainerPath) {
				pluginDict[@"Container"] = pluginContainerPath;
				pluginDict[@"EnvironmentVariables"] = constructEnvironmentVariablesForContainerPath(pluginContainerPath, pluginContainerized);
			}
			pluginDict[@"Path"] = pluginPath;
			pluginDict[@"PluginOwnerBundleID"] = appBundleID;
			pluginDict[@"SignerOrganization"] = @"Apple Inc.";
			pluginDict[@"SignatureVersion"] = @132352;
			pluginDict[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";

			NSString *pluginTeamIdentifier = constructTeamIdentifierForEntitlements(pluginEntitlements);
			if (pluginTeamIdentifier) pluginDict[@"TeamIdentifier"] = pluginTeamIdentifier;

			// Add plugin group containers

			NSDictionary *pluginAppGroupContainers = constructGroupsContainersForEntitlements(pluginEntitlements, NO);
			NSDictionary *pluginSystemGroupContainers = constructGroupsContainersForEntitlements(pluginEntitlements, YES);
			NSMutableDictionary *pluginGroupContainers = [NSMutableDictionary new];
			[pluginGroupContainers addEntriesFromDictionary:pluginAppGroupContainers];
			[pluginGroupContainers addEntriesFromDictionary:pluginSystemGroupContainers];
			if (pluginGroupContainers.count) {
				if (pluginAppGroupContainers.count) {
					pluginDict[@"HasAppGroupContainers"] = @YES;
				}
				if (pluginSystemGroupContainers.count) {
					pluginDict[@"HasSystemGroupContainers"] = @YES;
				}
				pluginDict[@"GroupContainers"] = pluginGroupContainers.copy;
			}

			[bundlePlugins setObject:pluginDict forKey:pluginBundleID];
		}
		[dictToRegister setObject:bundlePlugins forKey:@"_LSBundlePlugins"];

		if (![workspace registerApplicationDictionary:dictToRegister]) {
			NSLog(@"Error: Unable to register %@", path);
			NSLog(@"Used dictionary: {");
			[dictToRegister enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, BOOL *stop) {
				NSLog(@"%@ = %@", key, obj);
			}];
			NSLog(@"}");
			return false;
		}
	} else {
		NSURL *url = [NSURL fileURLWithPath:path];
		if (![workspace unregisterApplication:url]) {
			NSLog(@"Error: Unable to register %@", path);
			return false;
		}
	}
	return true;
}
