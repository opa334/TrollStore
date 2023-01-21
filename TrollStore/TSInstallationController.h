@import Foundation;

@interface TSInstallationController : NSObject

+ (void)presentInstallationAlertIfEnabledForFile:(NSString*)pathToIPA isRemoteInstall:(BOOL)remoteInstall completion:(void (^)(BOOL, NSError*))completionBlock;

+ (void)handleAppInstallFromFile:(NSString*)pathToIPA forceInstall:(BOOL)force completion:(void (^)(BOOL, NSError*))completion;
+ (void)handleAppInstallFromFile:(NSString*)pathToIPA completion:(void (^)(BOOL, NSError*))completion;

+ (void)handleAppInstallFromRemoteURL:(NSURL*)remoteURL completion:(void (^)(BOOL, NSError*))completion;

+ (void)installLdid;

@end