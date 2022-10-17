#import "TSApplicationsManager.h"
#import <TSUtil.h>

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
    NSError* error;
    NSDictionary* infoDict = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:infoPlistPath] error:&error];
    if(error)
    {
        NSLog(@"error getting info dict: %@", error);
    }
    return infoDict;
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

- (NSString*)versionStringForAppPath:(NSString*)appPath
{
    NSDictionary* infoDict = [self infoDictionaryForAppPath:appPath];
    NSString* versionString = infoDict[@"CFBundleShortVersionString"];

    if(!versionString)
    {
        versionString = infoDict[@"CFBundleVersion"];
    }

    return versionString;
}

- (NSError*)errorForCode:(int)code
{
    NSString* errorDescription = @"Unknown Error";
    switch(code)
    {
        // IPA install errors
        case 166:
        errorDescription = @"The IPA file does not exist or is not accessible.";
        break;
        case 167:
        errorDescription = @"The IPA file does not appear to contain an app.";
        break;
        // App install errors
        case 170:
        errorDescription = @"Failed to create container for app bundle.";
        break;
        case 171:
        errorDescription = @"A non-TrollStore app with the same identifier is already installed. If you are absolutely sure it is not, you can force install it.";
        break;
        case 172:
        errorDescription = @"The app does not contain an Info.plist file.";
        break;
        case 173:
        errorDescription = @"The app is not signed with a fake CoreTrust certificate and ldid is not installed. Install ldid in the settings tab and try again.";
        break;
        case 174:
        errorDescription = @"The app's main executable does not exist.";
        break;
        case 175:
        errorDescription = @"Failed to sign the app. ldid returned a non zero status code.";
        break;
        case 176:
        errorDescription = @"The app's Info.plist is missing required values.";
        break;
        case 177:
        errorDescription = @"Failed to mark app as TrollStore app.";
        break;
        case 178:
        errorDescription = @"Failed to copy app bundle.";
        break;
        case 179:
        errorDescription = @"The app you tried to install has the same identifier as a system app already installed on the device. The installation has been prevented to protect you from possible bootloops or other issues.";
        break;
        // App detach errors
        /*case 184:
        errorDescription = @"Refusing to detach, the app is still signed with a fake root certificate. The detach option is only for when you have installed an App Store app on top of a TrollStore app.";
        break;*/
    }

    NSError* error = [NSError errorWithDomain:TrollStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    return error;
}

- (int)installIpa:(NSString*)pathToIpa force:(BOOL)force log:(NSString**)logOut
{
    int ret;
    if(force)
    {
        ret = spawnRoot(rootHelperPath(), @[@"install", pathToIpa, @"force"], nil, logOut);
    }
    else
    {
        ret = spawnRoot(rootHelperPath(), @[@"install", pathToIpa], nil, logOut);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)installIpa:(NSString*)pathToIpa
{
    return [self installIpa:pathToIpa force:NO log:nil];
}

- (int)uninstallApp:(NSString*)appId
{
    if(!appId) return -200;
    int ret = spawnRoot(rootHelperPath(), @[@"uninstall", appId], nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallAppByPath:(NSString*)path
{
    if(!path) return -200;
    int ret = spawnRoot(rootHelperPath(), @[@"uninstall-path", path], nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (BOOL)openApplicationWithBundleID:(NSString *)appId
{
    return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:appId];
}

/*- (int)detachFromApp:(NSString*)appId
{
    if(!appId) return -200;
    int ret = spawnRoot(rootHelperPath(), @[@"detach", appId], nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}*/

@end