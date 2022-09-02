@import Foundation;
@import CoreServices;
#import "CoreServices.h"
#import <objc/runtime.h>
#import "dlfcn.h"

void registerPath(char *path, int unregister)
{
    if(!path) return;

    LSApplicationWorkspace *workspace =
        [LSApplicationWorkspace defaultWorkspace];
    if (unregister && ![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:path]]) {
        LSApplicationProxy *app = [LSApplicationProxy
            applicationProxyForIdentifier:[NSString stringWithUTF8String:path]];
        if (app.bundleURL)
            path = (char *)[[app bundleURL] fileSystemRepresentation];
    }

    NSString *rawPath = [NSString stringWithUTF8String:path];
    rawPath = [rawPath stringByResolvingSymlinksInPath];

    NSDictionary *infoPlist = [NSDictionary
        dictionaryWithContentsOfFile:
            [rawPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *bundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];

    NSURL *url = [NSURL fileURLWithPath:rawPath];

    if (bundleID && !unregister) {
        MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer")
            containerWithIdentifier:bundleID
                  createIfNecessary:YES
                            existed:nil
                              error:nil];
        NSString *containerPath = [appContainer url].path;

        NSMutableDictionary *plist = [NSMutableDictionary dictionary];
        [plist setObject:@"System" forKey:@"ApplicationType"];
        [plist setObject:@1 forKey:@"BundleNameIsLocalized"];
        [plist setObject:bundleID forKey:@"CFBundleIdentifier"];
        [plist setObject:@0 forKey:@"CompatibilityState"];
        if (containerPath) [plist setObject:containerPath forKey:@"Container"];
        [plist setObject:@0 forKey:@"IsDeletable"];
        [plist setObject:rawPath forKey:@"Path"];

        NSString *pluginsPath =
            [rawPath stringByAppendingPathComponent:@"PlugIns"];
        NSArray *plugins = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:pluginsPath
                                error:nil];

        NSMutableDictionary *bundlePlugins = [NSMutableDictionary dictionary];
        for (NSString *pluginName in plugins) {
            NSString *fullPath =
                [pluginsPath stringByAppendingPathComponent:pluginName];

            NSDictionary *infoPlist = [NSDictionary
                dictionaryWithContentsOfFile:
                    [fullPath stringByAppendingPathComponent:@"Info.plist"]];
            NSString *pluginBundleID =
                [infoPlist objectForKey:@"CFBundleIdentifier"];
            if (!pluginBundleID) continue;
            MCMContainer *pluginContainer =
                [objc_getClass("MCMPluginKitPluginDataContainer")
                    containerWithIdentifier:pluginBundleID
                          createIfNecessary:YES
                                    existed:nil
                                      error:nil];
            NSString *pluginContainerPath = [pluginContainer url].path;

            NSMutableDictionary *pluginPlist = [NSMutableDictionary dictionary];
            [pluginPlist setObject:@"PluginKitPlugin"
                            forKey:@"ApplicationType"];
            [pluginPlist setObject:@1 forKey:@"BundleNameIsLocalized"];
            [pluginPlist setObject:pluginBundleID forKey:@"CFBundleIdentifier"];
            [pluginPlist setObject:@0 forKey:@"CompatibilityState"];
            [pluginPlist setObject:pluginContainerPath forKey:@"Container"];
            [pluginPlist setObject:fullPath forKey:@"Path"];
            [pluginPlist setObject:bundleID forKey:@"PluginOwnerBundleID"];
            [bundlePlugins setObject:pluginPlist forKey:pluginBundleID];
        }
        [plist setObject:bundlePlugins forKey:@"_LSBundlePlugins"];
        if (![workspace registerApplicationDictionary:plist]) {
            fprintf(stderr, "Error: Unable to register %s\n", path);
        }
    } else {
        if (![workspace unregisterApplication:url]) {
            fprintf(stderr, "Error: Unable to unregister %s\n", path);
        }
    }
}