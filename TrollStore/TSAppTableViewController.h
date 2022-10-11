#import <UIKit/UIKit.h>

@interface TSAppTableViewController : UITableViewController
{
    UIImage* _placeholderIcon;
    NSArray* _cachedAppPaths;
    NSMutableDictionary* _cachedIcons;
}

@end