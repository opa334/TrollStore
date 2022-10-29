#import <UIKit/UIKit.h>
#import "TSAppInfo.h"

@interface TSAppTableViewController : UITableViewController <UISearchResultsUpdating, UIDocumentPickerDelegate>
{
    UIImage* _placeholderIcon;
    NSArray<TSAppInfo*>* _cachedAppInfos;
    NSMutableDictionary* _cachedIcons;
    UISearchController* _searchController;
	NSString* _searchKey;
}

@end