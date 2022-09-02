@import Foundation;
#import "CoreServices.h"
#import <objc/runtime.h>

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
    MCMAppContainer* appContainer = [objc_getClass("MCMAppContainer") containerWithIdentifier:@"com.opa334.TrollStore" createIfNecessary:NO existed:NULL error:&mcmError];
    if(!appContainer) return nil;
    return appContainer.url.path;
}

NSString* trollStoreAppPath()
{
    return [trollStorePath() stringByAppendingPathComponent:@"TrollStore.app"];
}

LSApplicationProxy* findPersistenceHelperApp(void)
{
    __block LSApplicationProxy* outProxy;
    [[LSApplicationWorkspace defaultWorkspace] enumerateApplicationsOfType:1 block:^(LSApplicationProxy* appProxy)
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
	}];
    return outProxy;
}