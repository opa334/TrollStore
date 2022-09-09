#import "TSSettingsListController.h"
#import "TSUtil.h"
#import <Preferences/PSSpecifier.h>
#import "../Helper/CoreServices.h"
#import "../Helper/Shared.h"

@implementation TSSettingsListController

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

		PSSpecifier* utilitiesGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		utilitiesGroupSpecifier.name = @"Utilities";
		[utilitiesGroupSpecifier setProperty:@"If an app does not immediately appear after installation, respring here and it should appear afterwards." forKey:@"footerText"];
		[_specifiers addObject:utilitiesGroupSpecifier];

		PSSpecifier* respringButtonSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Respring"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
		 respringButtonSpecifier.identifier = @"respring";
		[respringButtonSpecifier setProperty:@YES forKey:@"enabled"];
		respringButtonSpecifier.buttonAction = @selector(respringButtonPressed);

		[_specifiers addObject:respringButtonSpecifier];

		PSSpecifier* rebuildIconCacheSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Rebuild Icon Cache"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
		 rebuildIconCacheSpecifier.identifier = @"uicache";
		[rebuildIconCacheSpecifier setProperty:@YES forKey:@"enabled"];
		rebuildIconCacheSpecifier.buttonAction = @selector(rebuildIconCachePressed);

		[_specifiers addObject:rebuildIconCacheSpecifier];

		NSString* ldidPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"ldid"];
		BOOL ldidInstalled = [[NSFileManager defaultManager] fileExistsAtPath:ldidPath];

		PSSpecifier* signingGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		signingGroupSpecifier.name = @"Signing";

		if(ldidInstalled)
		{
			[signingGroupSpecifier setProperty:@"ldid is installed and allows TrollStore to install unsigned IPA files." forKey:@"footerText"];
		}
		else
		{
			[signingGroupSpecifier setProperty:@"In order for TrollStore to be able to install unsigned IPAs, ldid has to be installed using this button. It can't be directly included in TrollStore because of licensing issues." forKey:@"footerText"];
		}

		[_specifiers addObject:signingGroupSpecifier];

		if(ldidInstalled)
		{
			PSSpecifier* ldidInstalledSpecifier = [PSSpecifier preferenceSpecifierNamed:@"ldid: Installed"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
			[ldidInstalledSpecifier setProperty:@NO forKey:@"enabled"];
			ldidInstalledSpecifier.identifier = @"ldidInstalled";
			[_specifiers addObject:ldidInstalledSpecifier];
		}
		else
		{
			PSSpecifier* installLdidSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Install ldid"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
			installLdidSpecifier.identifier = @"ldidInstalled";
			[installLdidSpecifier setProperty:@YES forKey:@"enabled"];
			installLdidSpecifier.buttonAction = @selector(installLdidPressed);
			[_specifiers addObject:installLdidSpecifier];
		}

		PSSpecifier* persistenceGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		persistenceGroupSpecifier.name = @"Persistence";
		[_specifiers addObject:persistenceGroupSpecifier];

		if([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/TrollStorePersistenceHelper.app"])
		{
			[persistenceGroupSpecifier setProperty:@"When iOS rebuilds the icon cache, all TrollStore apps including TrollStore itself will be reverted to \"User\" state and either disappear or no longer launch. If that happens, you can use the TrollHelper app on the home screen to refresh the app registrations, which will make them work again." forKey:@"footerText"];
			PSSpecifier* installedPersistenceHelperSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Helper Installed as Standalone App"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
			[installedPersistenceHelperSpecifier setProperty:@NO forKey:@"enabled"];
			installedPersistenceHelperSpecifier.identifier = @"persistenceHelperInstalled";
			[_specifiers addObject:installedPersistenceHelperSpecifier];
		}
		else
		{
			LSApplicationProxy* persistenceApp = findPersistenceHelperApp();
			if(persistenceApp)
			{
				NSString* appName = [persistenceApp localizedName];

				[persistenceGroupSpecifier setProperty:[NSString stringWithFormat:@"When iOS rebuilds the icon cache, all TrollStore apps including TrollStore itself will be reverted to \"User\" state and either disappear or no longer launch. If that happens, you can use the persistence helper installed into %@ to refresh the app registrations, which will make them work again.", appName] forKey:@"footerText"];
				PSSpecifier* installedPersistenceHelperSpecifier = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"Helper Installed into %@", appName]
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSStaticTextCell
												edit:nil];
				[installedPersistenceHelperSpecifier setProperty:@NO forKey:@"enabled"];
				installedPersistenceHelperSpecifier.identifier = @"persistenceHelperInstalled";
				[_specifiers addObject:installedPersistenceHelperSpecifier];

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
			else
			{
				[persistenceGroupSpecifier setProperty:@"When iOS rebuilds the icon cache, all TrollStore apps including TrollStore itself will be reverted to \"User\" state and either disappear or no longer launch. The only way to have persistence in a rootless environment is to replace a system application, here you can select a system app to replace with a persistence helper that can be used to refresh the registrations of all TrollStore related apps in case they disappear or no longer launch." forKey:@"footerText"];

				_installPersistenceHelperSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Install Persistence Helper"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
				_installPersistenceHelperSpecifier.identifier = @"installPersistenceHelper";
				[_installPersistenceHelperSpecifier setProperty:@YES forKey:@"enabled"];
				_installPersistenceHelperSpecifier.buttonAction = @selector(installPersistenceHelperPressed);
				[_specifiers addObject:_installPersistenceHelperSpecifier];
			}
		}

		PSSpecifier* otherGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		[otherGroupSpecifier setProperty:[NSString stringWithFormat:@"TrollStore %@\n\n© 2022 Lars Fröder (opa334)\n\nCredits:\n@LinusHenze: CoreTrust bug\n@zhuowei: CoreTrust bug writeup and cert\n@lunotech11: Some contributions\n@ProcursusTeam: uicache and ldid build\n@cstar_ow: uicache\n@saurik: ldid", getTrollStoreVersion()] forKey:@"footerText"];
		[_specifiers addObject:otherGroupSpecifier];

		// Uninstall TrollStore
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

	[(UINavigationItem *)self.navigationItem setTitle:@"Settings"];
	return _specifiers;
}

- (void)respringButtonPressed
{
	respring();
}

- (void)rebuildIconCachePressed
{
	[self startActivity:@"Rebuilding Icon Cache"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		spawnRoot(helperPath(), @[@"refresh-all"], nil, nil);

		dispatch_async(dispatch_get_main_queue(), ^
		{
			[self stopActivityWithCompletion:nil];
		});
	});
}

- (void)installLdidPressed
{
	NSURL* ldidURL = [NSURL URLWithString:@"https://github.com/opa334/ldid/releases/download/v2.1.5-procursus5/ldid"];
	NSURLRequest* ldidRequest = [NSURLRequest requestWithURL:ldidURL];

	[self startActivity:@"Installing ldid"];

	NSURLSessionDownloadTask* downloadTask = [NSURLSession.sharedSession downloadTaskWithRequest:ldidRequest completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
	{
		if(error)
		{
			UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error downloading ldid: %@", error] preferredStyle:UIAlertControllerStyleAlert];
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
			spawnRoot(helperPath(), @[@"install-ldid", location.path], nil, nil);
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self stopActivityWithCompletion:nil];
				[self reloadSpecifiers];
			});
		}
	}];

	[downloadTask resume];
}

- (void)installPersistenceHelperPressed
{
	NSMutableArray* appCandidates = [NSMutableArray new];
	[[LSApplicationWorkspace defaultWorkspace] enumerateApplicationsOfType:1 block:^(LSApplicationProxy* appProxy)
	{
		if(appProxy.installed && !appProxy.restricted)
		{
			if([appProxy.bundleURL.path hasPrefix:@"/private/var/containers"])
			{
				NSURL* trollStoreMarkURL = [appProxy.bundleURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"_TrollStore"];
				if(![trollStoreMarkURL checkResourceIsReachableAndReturnError:nil])
				{
					[appCandidates addObject:appProxy];
				}
			}
		}
	}];

	UIAlertController* selectAppAlert = [UIAlertController alertControllerWithTitle:@"Select App" message:@"Select a system app to install the TrollStore Persistence Helper into. The normal function of the app will not be available, so it is recommended to pick something useless like the Tips app." preferredStyle:UIAlertControllerStyleActionSheet];
	for(LSApplicationProxy* appProxy in appCandidates)
	{
		UIAlertAction* installAction = [UIAlertAction actionWithTitle:[appProxy localizedName] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
		{
			spawnRoot(helperPath(), @[@"install-persistence-helper", appProxy.bundleIdentifier], nil, nil);
			[self reloadSpecifiers];
		}];

		[selectAppAlert addAction:installAction];
	}

	NSIndexPath* indexPath = [self indexPathForSpecifier:_installPersistenceHelperSpecifier];
	UITableView* tableView = [self valueForKey:@"_table"];
	selectAppAlert.popoverPresentationController.sourceView = tableView;
	selectAppAlert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[selectAppAlert addAction:cancelAction];

	[self presentViewController:selectAppAlert animated:YES completion:nil];
}

- (void)uninstallPersistenceHelperPressed
{
	spawnRoot(helperPath(), @[@"uninstall-persistence-helper"], nil, nil);
	[self reloadSpecifiers];
}

- (void)uninstallTrollStorePressed
{
	UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"About to uninstall TrollStore and all of the apps installed by it. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[uninstallWarningAlert addAction:cancelAction];

	UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		spawnRoot(helperPath(), @[@"uninstall-trollstore"], nil, nil);
		exit(0);
	}];
	[uninstallWarningAlert addAction:continueAction];

	[self presentViewController:uninstallWarningAlert animated:YES completion:nil];
}

@end