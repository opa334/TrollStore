#import "TSListControllerShared.h"

@interface TSSettingsListController : TSListControllerShared
{
    PSSpecifier* _installPersistenceHelperSpecifier;
    NSString* _newerVersion;
}
@end