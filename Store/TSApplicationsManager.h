#import <Foundation/Foundation.h>

#define TROLLSTORE_ROOT_PATH @"/var/containers/Bundle/TrollStore"
#define TROLLSTORE_MAIN_PATH [TROLLSTORE_ROOT_PATH stringByAppendingPathComponent:@"Main"]
#define TROLLSTORE_APPLICATIONS_PATH [TROLLSTORE_ROOT_PATH stringByAppendingPathComponent:@"Applications"]

@interface TSApplicationsManager : NSObject

+ (instancetype)sharedInstance;

- (NSArray*)installedAppPaths;
- (NSDictionary*)infoDictionaryForAppPath:(NSString*)appPath;
- (NSString*)appIdForAppPath:(NSString*)appPath;
- (NSString*)displayNameForAppPath:(NSString*)appPath;

- (int)installIpa:(NSString*)pathToIpa error:(NSError**)error;
- (int)uninstallApp:(NSString*)appId error:(NSError**)error;

@end