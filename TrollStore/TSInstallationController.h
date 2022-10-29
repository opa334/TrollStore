@import Foundation;

@interface TSInstallationController : NSObject

+ (void)presentInstallationAlertForFile:(NSString*)pathToIPA completion:(void (^)(BOOL, NSError*))completion;

+ (void)handleAppInstallFromFile:(NSString*)pathToIPA forceInstall:(BOOL)force completion:(void (^)(BOOL, NSError*))completion;
+ (void)handleAppInstallFromFile:(NSString*)pathToIPA completion:(void (^)(BOOL, NSError*))completion;

+ (void)handleAppInstallFromRemoteURL:(NSURL*)remoteURL completion:(void (^)(BOOL, NSError*))completion;

@end