#import "TSApplicationsManager.h"
#import "TSUtil.h"
#import "../Helper/Shared.h"

@implementation TSApplicationsManager

+ (instancetype)sharedInstance
{
    static TSApplicationsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TSApplicationsManager alloc] init];
    });
    return sharedInstance;
}

- (NSArray*)installedAppPaths
{
    return trollStoreInstalledAppBundlePaths();
}

- (NSDictionary*)infoDictionaryForAppPath:(NSString*)appPath
{
    NSString* infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    return [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
}

- (NSString*)appIdForAppPath:(NSString*)appPath
{
    return [self infoDictionaryForAppPath:appPath][@"CFBundleIdentifier"];
}

- (NSString*)displayNameForAppPath:(NSString*)appPath
{
    NSDictionary* infoDict = [self infoDictionaryForAppPath:appPath];
    
    NSString* displayName = infoDict[@"CFBundleDisplayName"];
    if(![displayName isKindOfClass:[NSString class]]) displayName = nil;
    if(!displayName || [displayName isEqualToString:@""])
    {
        displayName = infoDict[@"CFBundleName"];
        if(![displayName isKindOfClass:[NSString class]]) displayName = nil;
        if(!displayName || [displayName isEqualToString:@""])
        {
            displayName = infoDict[@"CFBundleExecutable"];
            if(![displayName isKindOfClass:[NSString class]]) displayName = [appPath lastPathComponent];
        }
    }

    return displayName;
}

- (int)installIpa:(NSString*)pathToIpa error:(NSError**)error
{
    int ret = spawnRoot(helperPath(), @[@"install", pathToIpa]) == 0;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallApp:(NSString*)appId error:(NSError**)error
{
    int ret = spawnRoot(helperPath(), @[@"uninstall", appId]) == 0;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

@end