#import <UIKit/UIKit.h>
#import "TSAppInfo.h"
#import <CoreServices.h>

@interface TSAppTableViewController : UITableViewController <UISearchResultsUpdating, UIDocumentPickerDelegate, LSApplicationWorkspaceObserverProtocol>
{
    UIImage* _placeholderIcon;
    NSArray<TSAppInfo*>* _cachedAppInfos;
    NSMutableDictionary* _cachedIcons;
    UISearchController* _searchController;
	NSString* _searchKey;
}

@end