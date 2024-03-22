#import "TSApplicationsManager.h"
#import <TSUtil.h>
extern NSUserDefaults* trollStoreUserDefaults();

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
        case 168:
        errorDescription = @"Failed to extract IPA file.";
        break;
        case 169:
        errorDescription = @"Failed to extract update tar file.";
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
        case 175: {
            //if (@available(iOS 16, *)) {
            //    errorDescription = @"Failed to sign the app.";
            //}
            //else {
                errorDescription = @"Failed to sign the app. ldid returned a non zero status code.";
            //}
        }
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
        case 180:
        errorDescription = @"The app you tried to install has an encrypted main binary, which cannot have the CoreTrust bypass applied to it. Please ensure you install decrypted apps.";
        break;
        case 181:
        errorDescription = @"Failed to add app to icon cache.";
        break;
        case 182:
        errorDescription = @"The app was installed successfully, but requires developer mode to be enabled to run. After rebooting, select \"Turn On\" to enable developer mode.";
        break;
        case 183:
        errorDescription = @"Failed to enable developer mode.";
        break;
        case 184:
        errorDescription = @"The app was installed successfully, but has additional binaries that are encrypted (e.g. extensions, plugins). The app itself should work, but you may experience broken functionality as a result.";
        case 185:
        errorDescription = @"Failed to sign the app. The CoreTrust bypass returned a non zero status code.";
    }

    NSError* error = [NSError errorWithDomain:TrollStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    return error;
}

- (int)installIpa:(NSString*)pathToIpa force:(BOOL)force log:(NSString**)logOut
{
    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"install"];
    if(force)
    {
        [args addObject:@"force"];
    }
    NSNumber* installationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"installationMethod"];
    int installationMethodToUse = installationMethodToUseNum ? installationMethodToUseNum.intValue : 1;
    if(installationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }
    [args addObject:pathToIpa];

    int ret = spawnRoot(rootHelperPath(), args, nil, logOut);
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

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"uninstall"];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }

    [args addObject:appId];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallAppByPath:(NSString*)path
{
    if(!path) return -200;

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"uninstall-path"];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }

    [args addObject:path];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (BOOL)openApplicationWithBundleID:(NSString *)appId
{
    return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:appId];
}

- (int)enableJITForBundleID:(NSString *)appId
{
    return spawnRoot(rootHelperPath(), @[@"enable-jit", appId], nil, nil);
}

- (int)changeAppRegistration:(NSString*)appPath toState:(NSString*)newState
{
    if(!appPath || !newState) return -200;
    return spawnRoot(rootHelperPath(), @[@"modify-registration", appPath, newState], nil, nil);
}

@end