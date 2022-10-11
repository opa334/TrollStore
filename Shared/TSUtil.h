@import Foundation;
#import "CoreServices.h"

extern void chineseWifiFixup(void);
extern void loadMCMFramework(void);
extern NSString* safe_getExecutablePath();
extern NSString* rootHelperPath(void);
extern NSString* getNSStringFromFile(int fd);
extern void printMultilineNSString(NSString* stringToPrint);
extern int spawnRoot(NSString* path, NSArray* args, NSString** stdOut, NSString** stdErr);
extern void respring(void);
extern void fetchLatestTrollStoreVersion(void (^completionHandler)(NSString* latestVersion));

extern NSArray* trollStoreInstalledAppBundlePaths();
extern NSArray* trollStoreInstalledAppContainerPaths();
extern NSString* trollStorePath();
extern NSString* trollStoreAppPath();

typedef enum
{
	PERSISTENCE_HELPER_TYPE_USER = 1 << 0,
	PERSISTENCE_HELPER_TYPE_SYSTEM = 1 << 1,
	PERSISTENCE_HELPER_TYPE_ALL = PERSISTENCE_HELPER_TYPE_USER | PERSISTENCE_HELPER_TYPE_SYSTEM
} PERSISTENCE_HELPER_TYPE;

extern LSApplicationProxy* findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE allowedTypes);