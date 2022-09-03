#import "TSPHRootViewController.h"
#import "../Helper/Shared.h"
#import "../Store/TSUtil.h"

@implementation TSPHRootViewController

- (void)loadView
{
	[super loadView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)startActivity:(NSString*)activity
{
	if(_activityController) return;

	_activityController = [UIAlertController alertControllerWithTitle:activity message:@"" preferredStyle:UIAlertControllerStyleAlert];
	UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(5,5,50,50)];
	activityIndicator.hidesWhenStopped = YES;
	activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
	[activityIndicator startAnimating];
	[_activityController.view addSubview:activityIndicator];

	[self presentViewController:_activityController animated:YES completion:nil];
}

- (void)stopActivityWithCompletion:(void (^)(void))completion
{
	if(!_activityController) return;

	[_activityController dismissViewControllerAnimated:YES completion:^
	{
		_activityController = nil;
		if(completion)
		{
			completion();
		}
	}];
}

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

		PSSpecifier* infoGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		infoGroupSpecifier.name = @"Info";
		[_specifiers addObject:infoGroupSpecifier];

		PSSpecifier* infoSpecifier = [PSSpecifier preferenceSpecifierNamed:@"TrollStore"
											target:self
											set:nil
											get:@selector(getTrollStoreInfoString)
											detail:nil
											cell:PSTitleValueCell
											edit:nil];
		infoSpecifier.identifier = @"info";
		[infoSpecifier setProperty:@YES forKey:@"enabled"];

		[_specifiers addObject:infoSpecifier];

		PSSpecifier* utilitiesGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		[_specifiers addObject:utilitiesGroupSpecifier];

		if(trollStoreAppPath())
		{
			PSSpecifier* refreshAppRegistrationsSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Refresh App Registrations"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			refreshAppRegistrationsSpecifier.identifier = @"refreshAppRegistrations";
			[refreshAppRegistrationsSpecifier setProperty:@YES forKey:@"enabled"];
			refreshAppRegistrationsSpecifier.buttonAction = @selector(refreshAppRegistrations);
			[_specifiers addObject:refreshAppRegistrationsSpecifier];

			PSSpecifier* uninstallTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Uninstall TrollStore"
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSButtonCell
										edit:nil];
			uninstallTrollStoreSpecifier.identifier = @"uninstallTrollStore";
			[uninstallTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
			[uninstallTrollStoreSpecifier setProperty:NSClassFromString(@"PSDeleteButtonCell") forKey:@"cellClass"];
			uninstallTrollStoreSpecifier.buttonAction = @selector(uninstallTrollStorePressed);
			[_specifiers addObject:uninstallTrollStoreSpecifier];
		}
		else
		{
			PSSpecifier* installTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Install TrollStore"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			installTrollStoreSpecifier.identifier = @"installTrollStore";
			[installTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
			installTrollStoreSpecifier.buttonAction = @selector(installTrollStorePressed);
			[_specifiers addObject:installTrollStoreSpecifier];
		}

		if(![NSBundle.mainBundle.bundleIdentifier hasPrefix:@"com.opa334."])
		{
			[_specifiers addObject:[PSSpecifier emptyGroupSpecifier]];

			PSSpecifier* uninstallPersistenceHelperSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Uninstall Persistence Helper"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			uninstallPersistenceHelperSpecifier.identifier = @"uninstallPersistenceHelper";
			[uninstallPersistenceHelperSpecifier setProperty:@YES forKey:@"enabled"];
			[uninstallPersistenceHelperSpecifier setProperty:NSClassFromString(@"PSDeleteButtonCell") forKey:@"cellClass"];
			uninstallPersistenceHelperSpecifier.buttonAction = @selector(uninstallPersistenceHelperPressed);
			[_specifiers addObject:uninstallPersistenceHelperSpecifier];
		}
	}
	
	[(UINavigationItem *)self.navigationItem setTitle:@"TrollStore Helper"];
	return _specifiers;
}

- (NSString*)getTrollStoreInfoString
{
	NSString* trollStore = trollStoreAppPath();
	if(!trollStore)
	{
		return @"Not Installed";
	}
	else
	{
		NSBundle* trollStoreBundle = [NSBundle bundleWithPath:trollStore];
		NSString* version = [trollStoreBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		return [NSString stringWithFormat:@"Installed, %@", version];
	}
}

- (void)refreshAppRegistrations
{
	[self startActivity:@"Refreshing"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		spawnRoot(helperPath(), @[@"refresh"]);
		respring();

		dispatch_async(dispatch_get_main_queue(), ^
		{
			[self stopActivityWithCompletion:nil];
		});
	});
}

- (void)installTrollStorePressed
{
	NSURL* trollStoreURL = [NSURL URLWithString:@"https://github.com/opa334/TrollStore/releases/latest/download/TrollStore.tar"];
	NSURLRequest* trollStoreRequest = [NSURLRequest requestWithURL:trollStoreURL];

	[self startActivity:@"Installing TrollStore"];

	NSURLSessionDownloadTask* downloadTask = [NSURLSession.sharedSession downloadTaskWithRequest:trollStoreRequest completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
	{
		if(error)
		{
			UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error downloading TrollStore: %@", error] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
			[errorAlert addAction:closeAction];

			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self stopActivityWithCompletion:^
				{
					[self presentViewController:errorAlert animated:YES completion:nil];
				}];
			});
		}
		else
		{
			NSString* tarTmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TrollStore.tar"];
			[[NSFileManager defaultManager] copyItemAtPath:location.path toPath:tarTmpPath error:nil];

			int ret = spawnRoot(helperPath(), @[@"install-trollstore", tarTmpPath]);
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[[NSFileManager defaultManager] removeItemAtPath:tarTmpPath error:nil];
				[self stopActivityWithCompletion:^
				{
					[self reloadSpecifiers];

					if(ret == 0)
					{
						respring();
					}
					else
					{
						UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error installing TrollStore: trollstorehelper returned %d", ret] preferredStyle:UIAlertControllerStyleAlert];
						UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
						[errorAlert addAction:closeAction];
						[self presentViewController:errorAlert animated:YES completion:nil];
					}
				}];
			});
		}
	}];

	[downloadTask resume];
}

- (void)uninstallTrollStorePressed
{
	UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"About to uninstall TrollStore and all of the apps installed by it. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[uninstallWarningAlert addAction:cancelAction];

	UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		spawnRoot(helperPath(), @[@"uninstall-trollstore"]);
		exit(0);
	}];
	[uninstallWarningAlert addAction:continueAction];

	[self presentViewController:uninstallWarningAlert animated:YES completion:nil];
}

- (void)uninstallPersistenceHelperPressed
{
	UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"Uninstalling the persistence helper will revert this app back to it's original state, you will however no longer be able to persistently refresh the TrollStore app registrations. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[uninstallWarningAlert addAction:cancelAction];

	UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		spawnRoot(helperPath(), @[@"uninstall-persistence-helper"]);
		exit(0);
	}];
	[uninstallWarningAlert addAction:continueAction];

	[self presentViewController:uninstallWarningAlert animated:YES completion:nil];
}

@end
