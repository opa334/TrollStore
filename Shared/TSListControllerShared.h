#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface TSListControllerShared : PSListController
{
    UIAlertController* _activityController;
}

- (BOOL)isTrollStore;
- (NSString*)getTrollStoreVersion;
- (void)downloadTrollStoreAndDo:(void (^)(NSString* localTrollStoreTarPath))doHandler;
- (void)installTrollStorePressed;
- (void)updateTrollStorePressed;
- (void)rebuildIconCachePressed;
- (void)refreshAppRegistrationsPressed;
- (void)uninstallPersistenceHelperPressed;
- (void)handleUninstallation;
- (void)uninstallTrollStorePressed;
@end