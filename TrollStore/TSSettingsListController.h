#import "TSListControllerShared.h"

@interface TSSettingsListController : TSListControllerShared
{
    PSSpecifier* _installPersistenceHelperSpecifier;
    NSString* _newerVersion;
    NSString* _newerLdidVersion;
    BOOL _devModeEnabled;
}
@end