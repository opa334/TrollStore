#import "TSApplicationsManager.h"
#import "TSUtil.h"
#import "../Helper/Shared.h"

#define TrollStoreErrorDomain @"TrollStoreErrorDomain"

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

- (NSError*)errorForCode:(int)code
{
    NSString* errorDescription = @"Unknown Error";
    switch(code)
    {
        case 166:
        errorDescription = @"The IPA file does not exist or is not accessible.";
        break;
        case 167:
        errorDescription = @"The IPA file does not appear to contain an app.";
        break;
        case 170:
        errorDescription = @"Failed to create container for app bundle.";
        break;
        case 171:
        errorDescription = @"A non-TrollStore app with the same identifier is already installed. If you are absolutely sure it is not, you can force install it.";
        break;
        case 172:
        errorDescription = @"The app does not seem to contain an Info.plist";
        break;
        case 173:
        errorDescription = @"The app is not signed with a fake CoreTrust certificate and ldid does not seem to be installed. Make sure ldid is installed in the settings tab and try again.";
        break;
    }

    NSError* error = [NSError errorWithDomain:TrollStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    return error;
}

- (int)installIpa:(NSString*)pathToIpa force:(BOOL)force
{
    int ret;
    if(force)
    {
        ret = spawnRoot(helperPath(), @[@"install", pathToIpa, @"force"]);
    }
    else
    {
        ret = spawnRoot(helperPath(), @[@"install", pathToIpa]);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)installIpa:(NSString*)pathToIpa
{
    return [self installIpa:pathToIpa force:NO];
}

- (int)uninstallApp:(NSString*)appId
{
    if(!appId) return -200;
    int ret = spawnRoot(helperPath(), @[@"uninstall", appId]);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallAppByPath:(NSString*)path
{
    if(!path) return -200;
    int ret = spawnRoot(helperPath(), @[@"uninstall-path", path]);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

@end