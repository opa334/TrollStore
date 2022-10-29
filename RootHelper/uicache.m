@import Foundation;
@import CoreServices;
#import "CoreServices.h"
#import <objc/runtime.h>
#import "dlfcn.h"

// uicache on steroids

extern NSSet<NSString*>* immutableAppBundleIdentifiers(void);
extern NSDictionary* dumpEntitlementsFromBinaryAtPath(NSString* binaryPath);

NSDictionary* constructGroupsContainersForEntitlements(NSDictionary* entitlements, BOOL systemGroups)
{
	if(!entitlements) return nil;

	NSString* entitlementForGroups;
	NSString* mcmClass;
	if(systemGroups)
	{
		entitlementForGroups = @"com.apple.security.system-groups";
		mcmClass = @"MCMSystemDataContainer";
	}
	else
	{
		entitlementForGroups = @"com.apple.security.application-groups";
		mcmClass = @"MCMSharedDataContainer";
	}

	NSArray* groupIDs = entitlements[entitlementForGroups];
	if(groupIDs && [groupIDs isKindOfClass:[NSArray class]])
	{
		NSMutableDictionary* groupContainers = [NSMutableDictionary new];

		for(NSString* groupID in groupIDs)
		{
			MCMContainer* container = [NSClassFromString(mcmClass) containerWithIdentifier:groupID createIfNecessary:YES existed:nil error:nil];
			if(container.url)
			{
				groupContainers[groupID] = container.url.path;
			}
		}

		return groupContainers.copy;
	}

	return nil;
}

BOOL constructContainerizationForEntitlements(NSDictionary* entitlements)
{
	NSNumber* noContainer = entitlements[@"com.apple.private.security.no-container"];
	if(noContainer && [noContainer isKindOfClass:[NSNumber class]])
	{
		if(noContainer.boolValue)
		{
			return NO;
		}
	}

	NSNumber* containerRequired = entitlements[@"com.apple.private.security.container-required"];
	if(containerRequired && [containerRequired isKindOfClass:[NSNumber class]])
	{
		if(!containerRequired.boolValue)
		{
			return NO;
		}
	}

	return YES;
}

NSString* constructTeamIdentifierForEntitlements(NSDictionary* entitlements)
{
	NSString* teamIdentifier = entitlements[@"com.apple.developer.team-identifier"];
	if(teamIdentifier && [teamIdentifier isKindOfClass:[NSString class]])
	{
		return teamIdentifier;
	}
	return nil;
}

NSDictionary* constructEnvironmentVariablesForContainerPath(NSString* containerPath)
{
	NSString* tmpDir = [containerPath stringByAppendingPathComponent:@"tmp"];
	return @{
		@"CFFIXED_USER_HOME" : containerPath,
		@"HOME" : containerPath,
		@"TMPDIR" : tmpDir
	};
}

void registerPath(char* cPath, int unregister, BOOL system)
{
	if(!cPath) return;
	NSString* path = [NSString stringWithUTF8String:cPath];

	LSApplicationWorkspace* workspace = [LSApplicationWorkspace defaultWorkspace];
	if(unregister && ![[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		LSApplicationProxy* app = [LSApplicationProxy applicationProxyForIdentifier:path];
		if(app.bundleURL)
		{
			path = [app bundleURL].path;
		}
	}

	path = [path stringByResolvingSymlinksInPath];

	NSDictionary* appInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
	NSString* appBundleID = [appInfoPlist objectForKey:@"CFBundleIdentifier"];

	if([immutableAppBundleIdentifiers() containsObject:appBundleID.lowercaseString]) return;

	if(appBundleID && !unregister)
	{
		MCMContainer* appContainer = [NSClassFromString(@"MCMAppDataContainer") containerWithIdentifier:appBundleID createIfNecessary:YES existed:nil error:nil];
		NSString* containerPath = [appContainer url].path;

		NSMutableDictionary* dictToRegister = [NSMutableDictionary dictionary];

		// Add entitlements

		NSString* appExecutablePath = [path stringByAppendingPathComponent:appInfoPlist[@"CFBundleExecutable"]];
        NSDictionary* entitlements = dumpEntitlementsFromBinaryAtPath(appExecutablePath);
		if(entitlements)
		{
			dictToRegister[@"Entitlements"] = entitlements;
		}

		// Misc

		dictToRegister[@"ApplicationType"] = system ? @"System" : @"User";
		dictToRegister[@"CFBundleIdentifier"] = appBundleID;
		dictToRegister[@"CodeInfoIdentifier"] = appBundleID;
		dictToRegister[@"CompatibilityState"] = @0;
		if(containerPath)
		{
			dictToRegister[@"Container"] = containerPath;
			dictToRegister[@"EnvironmentVariables"] = constructEnvironmentVariablesForContainerPath(containerPath);
		}
		dictToRegister[@"IsDeletable"] = @0;
		dictToRegister[@"Path"] = path;
		dictToRegister[@"IsContainerized"] = @(constructContainerizationForEntitlements(entitlements));
		dictToRegister[@"SignerOrganization"] = @"Apple Inc.";
		dictToRegister[@"SignatureVersion"] = @132352;
		dictToRegister[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";
		dictToRegister[@"IsAdHocSigned"] = @YES;
		dictToRegister[@"LSInstallType"] = @1;
		dictToRegister[@"HasMIDBasedSINF"] = @0;
		dictToRegister[@"MissingSINF"] = @0;
		dictToRegister[@"FamilyID"] = @0;
		dictToRegister[@"IsOnDemandInstallCapable"] = @0;

		NSString* teamIdentifier = constructTeamIdentifierForEntitlements(entitlements);
		if(teamIdentifier) dictToRegister[@"TeamIdentifier"] = teamIdentifier;

		// Add group containers

		NSDictionary* appGroupContainers = constructGroupsContainersForEntitlements(entitlements, NO);
		NSDictionary* systemGroupContainers = constructGroupsContainersForEntitlements(entitlements, NO);
		NSMutableDictionary* groupContainers = [NSMutableDictionary new];
		[groupContainers addEntriesFromDictionary:appGroupContainers];
		[groupContainers addEntriesFromDictionary:systemGroupContainers];
		if(groupContainers.count)
		{
			if(appGroupContainers.count)
			{
				dictToRegister[@"HasAppGroupContainers"] = @YES;
			}
			if(systemGroupContainers.count)
			{
				dictToRegister[@"HasSystemGroupContainers"] = @YES;
			}
			dictToRegister[@"GroupContainers"] = groupContainers.copy;
		}

		// Add plugins

		NSString* pluginsPath = [path stringByAppendingPathComponent:@"PlugIns"];
		NSArray* plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];

		NSMutableDictionary* bundlePlugins = [NSMutableDictionary dictionary];
		for (NSString* pluginName in plugins)
		{
			NSString* pluginPath = [pluginsPath stringByAppendingPathComponent:pluginName];

			NSDictionary* pluginInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[pluginPath stringByAppendingPathComponent:@"Info.plist"]];
			NSString* pluginBundleID = [pluginInfoPlist objectForKey:@"CFBundleIdentifier"];

			if(!pluginBundleID) continue;
			MCMContainer* pluginContainer = [NSClassFromString(@"MCMPluginKitPluginDataContainer") containerWithIdentifier:pluginBundleID createIfNecessary:YES existed:nil error:nil];
			NSString* pluginContainerPath = [pluginContainer url].path;

			NSMutableDictionary* pluginDict = [NSMutableDictionary dictionary];

			// Add entitlements

			NSString* pluginExecutablePath = [pluginPath stringByAppendingPathComponent:pluginInfoPlist[@"CFBundleExecutable"]];
            NSDictionary* pluginEntitlements = dumpEntitlementsFromBinaryAtPath(pluginExecutablePath);
			if(pluginEntitlements)
			{
				pluginDict[@"Entitlements"] = pluginEntitlements;
			}

			// Misc

			pluginDict[@"ApplicationType"] = @"PluginKitPlugin";
			pluginDict[@"CFBundleIdentifier"] = pluginBundleID;
			pluginDict[@"CodeInfoIdentifier"] = pluginBundleID;
			pluginDict[@"CompatibilityState"] = @0;
			if(pluginContainerPath)
			{
				pluginDict[@"Container"] = pluginContainerPath;
				pluginDict[@"EnvironmentVariables"] = constructEnvironmentVariablesForContainerPath(pluginContainerPath);
			}
			pluginDict[@"Path"] = pluginPath;
			pluginDict[@"PluginOwnerBundleID"] = appBundleID;
			pluginDict[@"IsContainerized"] = @(constructContainerizationForEntitlements(pluginEntitlements));
			pluginDict[@"SignerOrganization"] = @"Apple Inc.";
			pluginDict[@"SignatureVersion"] = @132352;
			pluginDict[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";

			NSString* pluginTeamIdentifier = constructTeamIdentifierForEntitlements(pluginEntitlements);
			if(pluginTeamIdentifier) pluginDict[@"TeamIdentifier"] = pluginTeamIdentifier;

			// Add plugin group containers

			NSDictionary* pluginAppGroupContainers = constructGroupsContainersForEntitlements(pluginEntitlements, NO);
			NSDictionary* pluginSystemGroupContainers = constructGroupsContainersForEntitlements(pluginEntitlements, NO);
			NSMutableDictionary* pluginGroupContainers = [NSMutableDictionary new];
			[pluginGroupContainers addEntriesFromDictionary:pluginAppGroupContainers];
			[pluginGroupContainers addEntriesFromDictionary:pluginSystemGroupContainers];
			if(pluginGroupContainers.count)
			{
				if(pluginAppGroupContainers.count)
				{
					pluginDict[@"HasAppGroupContainers"] = @YES;
				}
				if(pluginSystemGroupContainers.count)
				{
					pluginDict[@"HasSystemGroupContainers"] = @YES;
				}
				pluginDict[@"GroupContainers"] = pluginGroupContainers.copy;
			}

			[bundlePlugins setObject:pluginDict forKey:pluginBundleID];
		}
		[dictToRegister setObject:bundlePlugins forKey:@"_LSBundlePlugins"];

		if(![workspace registerApplicationDictionary:dictToRegister])
		{
			NSLog(@"Error: Unable to register %@", path);
		}
	}
	else
	{
		NSURL* url = [NSURL fileURLWithPath:path];
		if(![workspace unregisterApplication:url])
		{
			NSLog(@"Error: Unable to unregister %@", path);
		}
	}
}
