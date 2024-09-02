#import "TSSettingsListController.h"
#import <TSUtil.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListItemsController.h>
#import <TSPresentationDelegate.h>
#import "TSInstallationController.h"
#import "TSSettingsAdvancedListController.h"
#import "TSDonateListController.h"

@interface NSUserDefaults (Private)
- (instancetype)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end
extern NSUserDefaults* trollStoreUserDefaults(void);

@implementation TSSettingsListController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:@"TrollStoreReloadSettingsNotification" object:nil];

#ifndef TROLLSTORE_LITE
	fetchLatestTrollStoreVersion(^(NSString* latestVersion)
	{
		NSString* currentVersion = [self getTrollStoreVersion];
		NSComparisonResult result = [currentVersion compare:latestVersion options:NSNumericSearch];
		if(result == NSOrderedAscending)
		{
			_newerVersion = latestVersion;
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self reloadSpecifiers];
			});
		}
	});

	//if (@available(iOS 16, *)) {} else {
		fetchLatestLdidVersion(^(NSString* latestVersion)
		{
			NSString* ldidVersionPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"ldid.version"];
			NSString* ldidVersion = nil;
			NSData* ldidVersionData = [NSData dataWithContentsOfFile:ldidVersionPath];
			if(ldidVersionData)
			{
				ldidVersion = [[NSString alloc] initWithData:ldidVersionData encoding:NSUTF8StringEncoding];
			}
			
			if(![latestVersion isEqualToString:ldidVersion])
			{
				_newerLdidVersion = latestVersion;
				dispatch_async(dispatch_get_main_queue(), ^
				{
					[self reloadSpecifiers];
				});
			}
		});
	//}

	if (@available(iOS 16, *))
	{
		_devModeEnabled = spawnRoot(rootHelperPath(), @[@"check-dev-mode"], nil, nil) == 0;
	}
	else
	{
		_devModeEnabled = YES;
	}
#endif
	[self reloadSpecifiers];
}

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

#ifndef TROLLSTORE_LITE
		if(_newerVersion)
		{
			PSSpecifier* updateTrollStoreGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
			updateTrollStoreGroupSpecifier.name = @"Update Available";
			[_specifiers addObject:updateTrollStoreGroupSpecifier];

			PSSpecifier* updateTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"Update TrollStore to %@", _newerVersion]
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSButtonCell
										edit:nil];
			updateTrollStoreSpecifier.identifier = @"updateTrollStore";
			[updateTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
			updateTrollStoreSpecifier.buttonAction = @selector(updateTrollStorePressed);
			[_specifiers addObject:updateTrollStoreSpecifier];
		}

		if(!_devModeEnabled)
		{
			PSSpecifier* enableDevModeGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
			enableDevModeGroupSpecifier.name = @"Developer Mode";
			[enableDevModeGroupSpecifier setProperty:@"Some apps require developer mode enabled to launch. This requires a reboot to take effect." forKey:@"footerText"];
			[_specifiers addObject:enableDevModeGroupSpecifier];

			PSSpecifier* enableDevModeSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Enable Developer Mode"
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSButtonCell
										edit:nil];
			enableDevModeSpecifier.identifier = @"enableDevMode";
			[enableDevModeSpecifier setProperty:@YES forKey:@"enabled"];
			enableDevModeSpecifier.buttonAction = @selector(enableDevModePressed);
			[_specifiers addObject:enableDevModeSpecifier];
		}
#endif

		PSSpecifier* utilitiesGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		utilitiesGroupSpecifier.name = @"Utilities";

		NSString *utilitiesDescription = @"";
#ifdef TROLLSTORE_LITE
		if (shouldRegisterAsUserByDefault()) {
			utilitiesDescription = @"Apps will be registered as User by default since AppSync Unified is installed.\n\n";
		}
		else {
			utilitiesDescription = @"Apps will be registered as System by default since AppSync Unified is not installed. When apps loose their System registration and stop working, press \"Refresh App Registrations\" here to fix them.\n\n";
		}
#endif
		utilitiesDescription = [utilitiesDescription stringByAppendingString:@"If an app does not immediately appear after installation, respring here and it should appear afterwards."];

		[utilitiesGroupSpecifier setProperty:utilitiesDescription forKey:@"footerText"];
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

		PSSpecifier* refreshAppRegistrationsSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Refresh App Registrations"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
		refreshAppRegistrationsSpecifier.identifier = @"refreshAppRegistrations";
		[refreshAppRegistrationsSpecifier setProperty:@YES forKey:@"enabled"];
		refreshAppRegistrationsSpecifier.buttonAction = @selector(refreshAppRegistrationsPressed);

		[_specifiers addObject:refreshAppRegistrationsSpecifier];

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

		NSArray *inactiveBundlePaths = trollStoreInactiveInstalledAppBundlePaths();
		if (inactiveBundlePaths.count > 0) {
			PSSpecifier* transferAppsSpecifier = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"Transfer %zu "OTHER_APP_NAME@" %@", inactiveBundlePaths.count, inactiveBundlePaths.count > 1 ? @"Apps" : @"App"]
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
			transferAppsSpecifier.identifier = @"transferApps";
			[transferAppsSpecifier setProperty:@YES forKey:@"enabled"];
			transferAppsSpecifier.buttonAction = @selector(transferAppsPressed);

			[_specifiers addObject:transferAppsSpecifier];
		}

#ifndef TROLLSTORE_LITE
		//if (@available(iOS 16, *)) { } else {
			NSString* ldidPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"ldid"];
			NSString* ldidVersionPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"ldid.version"];
			BOOL ldidInstalled = [[NSFileManager defaultManager] fileExistsAtPath:ldidPath];

			NSString* ldidVersion = nil;
			NSData* ldidVersionData = [NSData dataWithContentsOfFile:ldidVersionPath];
			if(ldidVersionData)
			{
				ldidVersion = [[NSString alloc] initWithData:ldidVersionData encoding:NSUTF8StringEncoding];
			}

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
				NSString* installedTitle = @"ldid: Installed";
				if(ldidVersion)
				{
					installedTitle = [NSString stringWithFormat:@"%@ (%@)", installedTitle, ldidVersion];
				}

				PSSpecifier* ldidInstalledSpecifier = [PSSpecifier preferenceSpecifierNamed:installedTitle
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSStaticTextCell
												edit:nil];
				[ldidInstalledSpecifier setProperty:@NO forKey:@"enabled"];
				ldidInstalledSpecifier.identifier = @"ldidInstalled";
				[_specifiers addObject:ldidInstalledSpecifier];

				if(_newerLdidVersion && ![_newerLdidVersion isEqualToString:ldidVersion])
				{
					NSString* updateTitle = [NSString stringWithFormat:@"Update to %@", _newerLdidVersion];
					PSSpecifier* ldidUpdateSpecifier = [PSSpecifier preferenceSpecifierNamed:updateTitle
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
					ldidUpdateSpecifier.identifier = @"updateLdid";
					[ldidUpdateSpecifier setProperty:@YES forKey:@"enabled"];
					ldidUpdateSpecifier.buttonAction = @selector(installOrUpdateLdidPressed);
					[_specifiers addObject:ldidUpdateSpecifier];
				}
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
				installLdidSpecifier.identifier = @"installLdid";
				[installLdidSpecifier setProperty:@YES forKey:@"enabled"];
				installLdidSpecifier.buttonAction = @selector(installOrUpdateLdidPressed);
				[_specifiers addObject:installLdidSpecifier];
			}
		//}

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
			LSApplicationProxy* persistenceApp = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_ALL);
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
#endif

		PSSpecifier* installationSettingsGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		installationSettingsGroupSpecifier.name = @"Security";
		[installationSettingsGroupSpecifier setProperty:@"The URL Scheme, when enabled, will allow apps and websites to trigger TrollStore installations through the apple-magnifier://install?url=<IPA_URL> URL scheme and enable JIT through the apple-magnifier://enable-jit?bundle-id=<BUNDLE_ID> URL scheme." forKey:@"footerText"];

		[_specifiers addObject:installationSettingsGroupSpecifier];

		PSSpecifier* URLSchemeToggle = [PSSpecifier preferenceSpecifierNamed:@"URL Scheme Enabled"
										target:self
										set:@selector(setURLSchemeEnabled:forSpecifier:)
										get:@selector(getURLSchemeEnabledForSpecifier:)
										detail:nil
										cell:PSSwitchCell
										edit:nil];

		[_specifiers addObject:URLSchemeToggle];

		PSSpecifier* installAlertConfigurationSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Show Install Confirmation Alert"
										target:self
										set:@selector(setPreferenceValue:specifier:)
										get:@selector(readPreferenceValue:)
										detail:nil
										cell:PSLinkListCell
										edit:nil];

		installAlertConfigurationSpecifier.detailControllerClass = [PSListItemsController class];
		[installAlertConfigurationSpecifier setProperty:@"installationConfirmationValues" forKey:@"valuesDataSource"];
        [installAlertConfigurationSpecifier setProperty:@"installationConfirmationNames" forKey:@"titlesDataSource"];
		[installAlertConfigurationSpecifier setProperty:APP_ID forKey:@"defaults"];
		[installAlertConfigurationSpecifier setProperty:@"installAlertConfiguration" forKey:@"key"];
        [installAlertConfigurationSpecifier setProperty:@0 forKey:@"default"];

		[_specifiers addObject:installAlertConfigurationSpecifier];

		PSSpecifier* otherGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		[otherGroupSpecifier setProperty:[NSString stringWithFormat:@"%@ %@\n\n© 2022-2024 Lars Fröder (opa334)\n\nTrollStore is NOT for piracy!\n\nCredits:\nGoogle TAG, @alfiecg_dev: CoreTrust bug\n@lunotech11, @SerenaKit, @tylinux, @TheRealClarity, @dhinakg, @khanhduytran0: Various contributions\n@ProcursusTeam: uicache, ldid\n@cstar_ow: uicache\n@saurik: ldid", APP_NAME, [self getTrollStoreVersion]] forKey:@"footerText"];
		[_specifiers addObject:otherGroupSpecifier];

		PSSpecifier* advancedLinkSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Advanced"
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSLinkListCell
										edit:nil];
		advancedLinkSpecifier.detailControllerClass = [TSSettingsAdvancedListController class];
		[advancedLinkSpecifier setProperty:@YES forKey:@"enabled"];
		[_specifiers addObject:advancedLinkSpecifier];

		PSSpecifier* donateSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Donate"
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSLinkListCell
										edit:nil];
		donateSpecifier.detailControllerClass = [TSDonateListController class];
		[donateSpecifier setProperty:@YES forKey:@"enabled"];
		[_specifiers addObject:donateSpecifier];

#ifndef TROLLSTORE_LITE
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
#endif
		/*PSSpecifier* doTheDashSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Do the Dash"
										target:self
										set:nil
										get:nil
										detail:nil
										cell:PSButtonCell
										edit:nil];
		doTheDashSpecifier.identifier = @"doTheDash";
		[doTheDashSpecifier setProperty:@YES forKey:@"enabled"];
		uninstallTrollStoreSpecifier.buttonAction = @selector(doTheDashPressed);
		[_specifiers addObject:doTheDashSpecifier];*/
	}

	[(UINavigationItem *)self.navigationItem setTitle:@"Settings"];
	return _specifiers;
}

- (NSArray*)installationConfirmationValues
{
	return @[@0, @1, @2];
}

- (NSArray*)installationConfirmationNames
{
	return @[@"Always (Recommended)", @"Only on Remote URL Installs", @"Never (Not Recommeded)"];
}

- (void)respringButtonPressed
{
	respring();
}

- (void)installOrUpdateLdidPressed
{
	[TSInstallationController installLdid];
}

- (void)enableDevModePressed
{
	int ret = spawnRoot(rootHelperPath(), @[@"arm-dev-mode"], nil, nil);

	if (ret == 0) {
		UIAlertController* rebootNotification = [UIAlertController alertControllerWithTitle:@"Reboot Required"
			message:@"After rebooting, select \"Turn On\" to enable developer mode."
			preferredStyle:UIAlertControllerStyleAlert
		];
		UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action)
		{
			[self reloadSpecifiers];
		}];
		[rebootNotification addAction:closeAction];

		UIAlertAction* rebootAction = [UIAlertAction actionWithTitle:@"Reboot Now" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
		{
			spawnRoot(rootHelperPath(), @[@"reboot"], nil, nil);
		}];
		[rebootNotification addAction:rebootAction];

		[TSPresentationDelegate presentViewController:rebootNotification animated:YES completion:nil];
	} else {
		UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Error %d", ret] message:@"Failed to enable developer mode." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
		[errorAlert addAction:closeAction];

		[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
	}
}

- (void)installPersistenceHelperPressed
{
	NSMutableArray* appCandidates = [NSMutableArray new];
	[[LSApplicationWorkspace defaultWorkspace] enumerateApplicationsOfType:1 block:^(LSApplicationProxy* appProxy)
	{
		if(appProxy.installed && !appProxy.restricted)
		{
			if([[NSFileManager defaultManager] fileExistsAtPath:[@"/System/Library/AppSignatures" stringByAppendingPathComponent:appProxy.bundleIdentifier]])
			{
				NSURL* trollStoreMarkURL = [appProxy.bundleURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:TS_ACTIVE_MARKER];
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
			spawnRoot(rootHelperPath(), @[@"install-persistence-helper", appProxy.bundleIdentifier], nil, nil);
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

	[TSPresentationDelegate presentViewController:selectAppAlert animated:YES completion:nil];
}

- (void)transferAppsPressed
{
	UIAlertController *confirmationAlert = [UIAlertController alertControllerWithTitle:@"Transfer Apps" message:[NSString stringWithFormat:@"This option will transfer %zu apps from "OTHER_APP_NAME@" to "APP_NAME@". Continue?", trollStoreInactiveInstalledAppBundlePaths().count] preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* transferAction = [UIAlertAction actionWithTitle:@"Transfer" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[TSPresentationDelegate startActivity:@"Transfering"];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
		{
			NSString *log;
			int transferRet = spawnRoot(rootHelperPath(), @[@"transfer-apps"], nil, &log);

			dispatch_async(dispatch_get_main_queue(), ^
			{
				[TSPresentationDelegate stopActivityWithCompletion:^
				{
					[self reloadSpecifiers];

					if (transferRet != 0) {
						NSArray *remainingApps = trollStoreInactiveInstalledAppBundlePaths();
						UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Transfer Failed" message:[NSString stringWithFormat:@"Failed to transfer %zu %@", remainingApps.count, remainingApps.count > 1 ? @"apps" : @"app"] preferredStyle:UIAlertControllerStyleAlert];

						UIAlertAction* copyLogAction = [UIAlertAction actionWithTitle:@"Copy Debug Log" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
						{
							UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
							pasteboard.string = log;
						}];
						[errorAlert addAction:copyLogAction];

						UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
						[errorAlert addAction:closeAction];

						[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
					}
				}];
			});
		});
	}];
	[confirmationAlert addAction:transferAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[confirmationAlert addAction:cancelAction];

	[TSPresentationDelegate presentViewController:confirmationAlert animated:YES completion:nil];
}

- (id)getURLSchemeEnabledForSpecifier:(PSSpecifier*)specifier
{
	BOOL URLSchemeActive = (BOOL)[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"];
	return @(URLSchemeActive);
}

- (void)setURLSchemeEnabled:(id)value forSpecifier:(PSSpecifier*)specifier
{
	NSNumber* newValue = value;
	NSString* newStateString = [newValue boolValue] ? @"enable" : @"disable";
	spawnRoot(rootHelperPath(), @[@"url-scheme", newStateString], nil, nil);

	UIAlertController* rebuildNoticeAlert = [UIAlertController alertControllerWithTitle:@"URL Scheme Changed" message:@"In order to properly apply the change of the URL scheme setting, rebuilding the icon cache is needed." preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction* rebuildNowAction = [UIAlertAction actionWithTitle:@"Rebuild Now" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[self rebuildIconCachePressed];
	}];
	[rebuildNoticeAlert addAction:rebuildNowAction];

	UIAlertAction* rebuildLaterAction = [UIAlertAction actionWithTitle:@"Rebuild Later" style:UIAlertActionStyleCancel handler:nil];
	[rebuildNoticeAlert addAction:rebuildLaterAction];

	[TSPresentationDelegate presentViewController:rebuildNoticeAlert animated:YES completion:nil];
}

- (void)doTheDashPressed
{
	spawnRoot(rootHelperPath(), @[@"dash"], nil, nil);
}

- (void)setPreferenceValue:(NSObject*)value specifier:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	[tsDefaults setObject:value forKey:[specifier propertyForKey:@"key"]];
}

- (NSObject*)readPreferenceValue:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	NSObject* toReturn = [tsDefaults objectForKey:[specifier propertyForKey:@"key"]];
	if(!toReturn)
	{
		toReturn = [specifier propertyForKey:@"default"];
	}
	return toReturn;
}

- (NSMutableArray*)argsForUninstallingTrollStore
{
	NSMutableArray* args = @[@"uninstall-trollstore"].mutableCopy;

	NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }

	return args;
}

@end