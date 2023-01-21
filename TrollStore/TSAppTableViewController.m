#import "TSAppTableViewController.h"

#import "TSApplicationsManager.h"
#import <TSPresentationDelegate.h>
#import "TSInstallationController.h"
#import "TSUtil.h"
@import UniformTypeIdentifiers;

#define ICON_FORMAT_IPAD 8
#define ICON_FORMAT_IPHONE 10

NSInteger iconFormatToUse(void)
{
	if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		return ICON_FORMAT_IPAD;
	}
	else
	{
		return ICON_FORMAT_IPHONE;
	}
}

UIImage* imageWithSize(UIImage* image, CGSize size)
{
	if(CGSizeEqualToSize(image.size, size)) return image;
	UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
	CGRect imageRect = CGRectMake(0.0, 0.0, size.width, size.height);
	[image drawInRect:imageRect];
	UIImage* outImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return outImage;
}

@interface UIImage ()
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)id format:(NSInteger)format scale:(double)scale;
@end

@implementation TSAppTableViewController

- (void)loadAppInfos
{
	NSArray* appPaths = [[TSApplicationsManager sharedInstance] installedAppPaths];
	NSMutableArray<TSAppInfo*>* appInfos = [NSMutableArray new];

	for(NSString* appPath in appPaths)
	{
		TSAppInfo* appInfo = [[TSAppInfo alloc] initWithAppBundlePath:appPath];
		[appInfo sync_loadBasicInfo];
		[appInfos addObject:appInfo];
	}

	if(_searchKey && ![_searchKey isEqualToString:@""])
	{
		[appInfos enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TSAppInfo* appInfo, NSUInteger idx, BOOL* stop)
		{
			NSString* appName = [appInfo displayName];
			BOOL nameMatch = [appName rangeOfString:_searchKey options:NSCaseInsensitiveSearch range:NSMakeRange(0, [appName length]) locale:[NSLocale currentLocale]].location != NSNotFound;
			if(!nameMatch)
			{
				[appInfos removeObjectAtIndex:idx];
			}
		}];
	}

	[appInfos sortUsingComparator:^(TSAppInfo* appInfoA, TSAppInfo* appInfoB)
	{
		return [[appInfoA displayName] localizedStandardCompare:[appInfoB displayName]];
	}];

	_cachedAppInfos = appInfos.copy;
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		[self loadAppInfos];
		_placeholderIcon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet" format:iconFormatToUse() scale:[UIScreen mainScreen].scale];
		_cachedIcons = [NSMutableDictionary new];
		[[LSApplicationWorkspace defaultWorkspace] addObserver:self];
	}
	return self;
}

- (void)dealloc
{
	[[LSApplicationWorkspace defaultWorkspace] removeObserver:self];
}

- (void)reloadTable
{
	[self loadAppInfos];
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[self.tableView reloadData];
	});
}

- (void)loadView
{
	[super loadView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"ApplicationsChanged" object:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.tableView.allowsMultipleSelectionDuringEditing = NO;
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

	[self _setUpNavigationBar];
	[self _setUpSearchBar];
}

- (void)_setUpNavigationBar
{
	UIAction* installFromFileAction = [UIAction actionWithTitle:@"Install IPA File" image:[UIImage systemImageNamed:@"doc.badge.plus"] identifier:@"InstallIPAFile" handler:^(__kindof UIAction *action)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			UTType* ipaType = [UTType typeWithFilenameExtension:@"ipa" conformingToType:UTTypeData];
			UTType* tipaType = [UTType typeWithFilenameExtension:@"tipa" conformingToType:UTTypeData];

			UIDocumentPickerViewController* documentPickerVC = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ipaType, tipaType]];
			documentPickerVC.allowsMultipleSelection = NO;
			documentPickerVC.delegate = self;

			[TSPresentationDelegate presentViewController:documentPickerVC animated:YES completion:nil];
		});
	}];

	UIAction* installFromURLAction = [UIAction actionWithTitle:@"Install from URL" image:[UIImage systemImageNamed:@"link.badge.plus"] identifier:@"InstallFromURL" handler:^(__kindof UIAction *action)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			UIAlertController* installURLController = [UIAlertController alertControllerWithTitle:@"Install from URL" message:@"" preferredStyle:UIAlertControllerStyleAlert];

			[installURLController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = @"URL";
			}];

			UIAlertAction* installAction = [UIAlertAction actionWithTitle:@"Install" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
			{
				NSString* URLString = installURLController.textFields.firstObject.text;
				NSURL* remoteURL = [NSURL URLWithString:URLString];

				[TSInstallationController handleAppInstallFromRemoteURL:remoteURL completion:nil];
			}];
			[installURLController addAction:installAction];

			UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
			[installURLController addAction:cancelAction];

			[TSPresentationDelegate presentViewController:installURLController animated:YES completion:nil];
		});
	}];

	UIMenu* installMenu = [UIMenu menuWithChildren:@[installFromFileAction, installFromURLAction]];

	UIBarButtonItem* installBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"] menu:installMenu];
	
	self.navigationItem.rightBarButtonItems = @[installBarButtonItem];
}

- (void)_setUpSearchBar
{
	_searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	_searchController.searchResultsUpdater = self;
	_searchController.obscuresBackgroundDuringPresentation = NO;
	self.navigationItem.searchController = _searchController;
	self.navigationItem.hidesSearchBarWhenScrolling = YES;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		_searchKey = searchController.searchBar.text;
		[self reloadTable];
	});
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSString* pathToIPA = urls.firstObject.path;
	[TSInstallationController presentInstallationAlertIfEnabledForFile:pathToIPA isRemoteInstall:NO completion:nil];
}

- (void)openAppPressedForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TSApplicationsManager* appsManager = [TSApplicationsManager sharedInstance];

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];
	NSString* appId = [appInfo bundleIdentifier];
	BOOL didOpen = [appsManager openApplicationWithBundleID:appId];

	// if we failed to open the app, show an alert
	if(!didOpen)
	{
		NSString* failMessage = @"";
		if([[appInfo registrationState] isEqualToString:@"User"])
		{
			failMessage = @"This app was not able to launch because it has a \"User\" registration state, register it as \"System\" and try again.";
		}

		NSString* failTitle = [NSString stringWithFormat:@"Failed to open %@", appId];
		UIAlertController* didFailController = [UIAlertController alertControllerWithTitle:failTitle message:failMessage preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

		[didFailController addAction:cancelAction];
		[TSPresentationDelegate presentViewController:didFailController animated:YES completion:nil];
	}
}

- (void)showDetailsPressedForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	[appInfo loadInfoWithCompletion:^(NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			if(!error)
			{
				UIAlertController* detailsAlert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
				detailsAlert.attributedTitle = [appInfo detailedInfoTitle];
				detailsAlert.attributedMessage = [appInfo detailedInfoDescription];

				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
				[detailsAlert addAction:closeAction];

				[TSPresentationDelegate presentViewController:detailsAlert animated:YES completion:nil];
			}
			else
			{
				UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Parse Error %ld", error.code] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
				[errorAlert addAction:closeAction];

				[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
			}
		});
	}];
}

- (void)changeAppRegistrationForRowAtIndexPath:(NSIndexPath*)indexPath toState:(NSString*)newState
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	if([newState isEqualToString:@"User"])
	{
		NSString* title = [NSString stringWithFormat:@"Switching '%@' to \"User\" Registration", [appInfo displayName]];
		UIAlertController* confirmationAlert = [UIAlertController alertControllerWithTitle:title message:@"Switching this app to a \"User\" registration will make it unlaunchable after the next respring because the bugs exploited in TrollStore only affect apps registered as \"System\".\nThe purpose of this option is to make the app temporarily show up in settings, so you can adjust the settings and then switch it back to a \"System\" registration (TrollStore installed apps do not show up in settings otherwise). Additionally, the \"User\" registration state is also useful to temporarily fix iTunes file sharing, which also doesn't work for TrollStore installed apps otherwise.\nWhen you're done making the changes you need and want the app to become launchable again, you will need to switch it back to \"System\" state in TrollStore." preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* switchToUserAction = [UIAlertAction actionWithTitle:@"Switch to \"User\"" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
		{
			[[TSApplicationsManager sharedInstance] changeAppRegistration:[appInfo bundlePath] toState:newState];
			[appInfo sync_loadBasicInfo];
		}];

		[confirmationAlert addAction:switchToUserAction];

		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

		[confirmationAlert addAction:cancelAction];

		[TSPresentationDelegate presentViewController:confirmationAlert animated:YES completion:nil];
	}
	else
	{
		[[TSApplicationsManager sharedInstance] changeAppRegistration:[appInfo bundlePath] toState:newState];
		[appInfo sync_loadBasicInfo];

		NSString* title = [NSString stringWithFormat:@"Switched '%@' to \"System\" Registration", [appInfo displayName]];

		UIAlertController* infoAlert = [UIAlertController alertControllerWithTitle:title message:@"The app has been switched to the \"System\" registration state and will become launchable again after a respring." preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
		{
			respring();
		}];

		[infoAlert addAction:respringAction];

		UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];

		[infoAlert addAction:closeAction];

		[TSPresentationDelegate presentViewController:infoAlert animated:YES completion:nil];
	}
}

- (void)uninstallPressedForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TSApplicationsManager* appsManager = [TSApplicationsManager sharedInstance];

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	NSString* appPath = [appInfo bundlePath];
	NSString* appId = [appInfo bundleIdentifier];
	NSString* appName = [appInfo displayName];

	UIAlertController* confirmAlert = [UIAlertController alertControllerWithTitle:@"Confirm Uninstallation" message:[NSString stringWithFormat:@"Uninstalling the app '%@' will delete the app and all data associated to it.", appName] preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* uninstallAction = [UIAlertAction actionWithTitle:@"Uninstall" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		if(appId)
		{
			[appsManager uninstallApp:appId];
		}
		else
		{
			[appsManager uninstallAppByPath:appPath];
		}
	}];
	[confirmAlert addAction:uninstallAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[confirmAlert addAction:cancelAction];

	[TSPresentationDelegate presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)deselectRow
{
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _cachedAppInfos.count;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
	[self reloadTable];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ApplicationCell"];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ApplicationCell"];
	}

	if(!indexPath || indexPath.row > (_cachedAppInfos.count - 1)) return cell;

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];
	NSString* appId = [appInfo bundleIdentifier];
	NSString* appVersion = [appInfo versionString];

	// Configure the cell...
	cell.textLabel.text = [appInfo displayName];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", appVersion, appId];
	cell.imageView.layer.borderWidth = 1;
	cell.imageView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.1].CGColor;
	cell.imageView.layer.cornerRadius = 13.5;
	cell.imageView.layer.masksToBounds = YES;
	cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;

	if(appId)
	{
		UIImage* cachedIcon = _cachedIcons[appId];
		if(cachedIcon)
		{
			cell.imageView.image = cachedIcon;
		}
		else
		{
			cell.imageView.image = _placeholderIcon;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
			{
				//usleep(1000 * 5000); // (test delay for debugging)
				UIImage* iconImage = imageWithSize([UIImage _applicationIconImageForBundleIdentifier:appId format:iconFormatToUse() scale:[UIScreen mainScreen].scale], _placeholderIcon.size);
				_cachedIcons[appId] = iconImage;
				dispatch_async(dispatch_get_main_queue(), ^{
					if([tableView.indexPathsForVisibleRows containsObject:indexPath])
					{
						cell.imageView.image = iconImage;
						[cell setNeedsLayout];
					}
				});
			});
		}
	}
	else
	{
		cell.imageView.image = _placeholderIcon;
	}

	cell.preservesSuperviewLayoutMargins = NO;
	cell.separatorInset = UIEdgeInsetsZero;
	cell.layoutMargins = UIEdgeInsetsZero;

	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 80.0f;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(editingStyle == UITableViewCellEditingStyleDelete)
	{
		[self uninstallPressedForRowAtIndexPath:indexPath];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	NSString* appId = [appInfo bundleIdentifier];
	NSString* appName = [appInfo displayName];

	UIAlertController* appSelectAlert = [UIAlertController alertControllerWithTitle:appName?:@"" message:appId?:@"" preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction* openAction = [UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[self openAppPressedForRowAtIndexPath:indexPath];
		[self deselectRow];
	}];
	[appSelectAlert addAction:openAction];

	UIAlertAction* showDetailsAction = [UIAlertAction actionWithTitle:@"Show Details" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[self showDetailsPressedForRowAtIndexPath:indexPath];
		[self deselectRow];
	}];
	[appSelectAlert addAction:showDetailsAction];

	NSString* switchState;
	NSString* registrationState = [appInfo registrationState];
	UIAlertActionStyle switchActionStyle = 0;
	if([registrationState isEqualToString:@"System"])
	{
		switchState = @"User";
		switchActionStyle = UIAlertActionStyleDestructive;
	}
	else if([registrationState isEqualToString:@"User"])
	{
		switchState = @"System";
		switchActionStyle = UIAlertActionStyleDefault;
	}

	UIAlertAction* switchRegistrationAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Switch to \"%@\" Registration", switchState] style:switchActionStyle handler:^(UIAlertAction* action)
	{
		[self changeAppRegistrationForRowAtIndexPath:indexPath toState:switchState];
		[self deselectRow];
	}];
	[appSelectAlert addAction:switchRegistrationAction];

	UIAlertAction* uninstallAction = [UIAlertAction actionWithTitle:@"Uninstall App" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		[self uninstallPressedForRowAtIndexPath:indexPath];
		[self deselectRow];
	}];
	[appSelectAlert addAction:uninstallAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action)
	{
		[self deselectRow];
	}];
	[appSelectAlert addAction:cancelAction];

	appSelectAlert.popoverPresentationController.sourceView = tableView;
	appSelectAlert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];

	[TSPresentationDelegate presentViewController:appSelectAlert animated:YES completion:nil];
}

- (void)applicationsDidInstall:(id)arg1
{
	[self reloadTable];
}

- (void)applicationsDidUninstall:(id)arg1
{
	[self reloadTable];
}

@end