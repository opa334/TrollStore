#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface TSSettingsListController : PSListController
{
    UIAlertController* _activityController;
    PSSpecifier* _installPersistenceHelperSpecifier;
}
@end