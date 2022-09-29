@import Foundation;

extern void chineseWifiFixup(void);
extern NSString* helperPath(void);
extern void printMultilineNSString(NSString* stringToPrint);
extern int spawnRoot(NSString* path, NSArray* args, NSString** stdOut, NSString** stdErr);
extern void respring(void);
extern void fetchLatestTrollStoreVersion(void (^completionHandler)(NSString* latestVersion));