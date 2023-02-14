#import "TSListControllerShared.h"
#import "TSUtil.h"
#import "TSPresentationDelegate.h"

@implementation TSListControllerShared

- (BOOL)isTrollStore
{
	return YES;
}

- (NSString*)getTrollStoreVersion
{
	if([self isTrollStore])
	{
		return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
	}
	else
	{
		NSString* trollStorePath = trollStoreAppPath();
		if(!trollStorePath) return nil;

		NSBundle* trollStoreBundle = [NSBundle bundleWithPath:trollStorePath];
		return [trollStoreBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
	}
}

- (void)downloadTrollStoreAndDo:(void (^)(NSString* localTrollStoreTarPath))doHandler
{
	NSURL* trollStoreURL = [NSURL URLWithString:@"https://github.com/opa334/TrollStore/releases/latest/download/TrollStore.tar"];
	NSURLRequest* trollStoreRequest = [NSURLRequest requestWithURL:trollStoreURL];

	NSURLSessionDownloadTask* downloadTask = [NSURLSession.sharedSession downloadTaskWithRequest:trollStoreRequest completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
	{
		if(error)
		{
			UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error downloading TrollStore: %@", error] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
			[errorAlert addAction:closeAction];

			dispatch_async(dispatch_get_main_queue(), ^
			{
				[TSPresentationDelegate stopActivityWithCompletion:^
				{
					[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
				}];
			});
		}
		else
		{
			NSString* tarTmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TrollStore.tar"];
			[[NSFileManager defaultManager] removeItemAtPath:tarTmpPath error:nil];
			[[NSFileManager defaultManager] copyItemAtPath:location.path toPath:tarTmpPath error:nil];

			doHandler(tarTmpPath);
		}
	}];

	[downloadTask resume];
}

- (void)_updateOrInstallTrollStore:(BOOL)update
{
	if(update)
	{
		[TSPresentationDelegate startActivity:@"Updating TrollStore"];
	}
	else
	{
		[TSPresentationDelegate startActivity:@"Installing TrollStore"];
	}

	[self downloadTrollStoreAndDo:^(NSString* tmpTarPath)
	{
		int ret = spawnRoot(rootHelperPath(), @[@"install-trollstore", tmpTarPath], nil, nil);
		[[NSFileManager defaultManager] removeItemAtPath:tmpTarPath error:nil];

		if(ret == 0)
		{
			respring();

			if([self isTrollStore])
			{
				exit(0);
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^
				{
					[TSPresentationDelegate stopActivityWithCompletion:^
					{
						[self reloadSpecifiers];
					}];
				});
			}
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[TSPresentationDelegate stopActivityWithCompletion:^
				{
					UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error installing TrollStore: trollstorehelper returned %d", ret] preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
					[errorAlert addAction:closeAction];
					[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
				}];
			});
		}
	}];
}

- (void)installTrollStorePressed
{
	[self _updateOrInstallTrollStore:NO];
}

- (void)updateTrollStorePressed
{
	[self _updateOrInstallTrollStore:YES];
}

- (void)rebuildIconCachePressed
{
	[TSPresentationDelegate startActivity:@"Rebuilding Icon Cache"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		spawnRoot(rootHelperPath(), @[@"refresh-all"], nil, nil);

		dispatch_async(dispatch_get_main_queue(), ^
		{
			[TSPresentationDelegate stopActivityWithCompletion:nil];
		});
	});
}

- (void)refreshAppRegistrationsPressed
{
	[TSPresentationDelegate startActivity:@"Refreshing"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		spawnRoot(rootHelperPath(), @[@"refresh"], nil, nil);
		respring();

		dispatch_async(dispatch_get_main_queue(), ^
		{
			[TSPresentationDelegate stopActivityWithCompletion:nil];
		});
	});
}

- (void)uninstallPersistenceHelperPressed
{
	if([self isTrollStore])
	{
		spawnRoot(rootHelperPath(), @[@"uninstall-persistence-helper"], nil, nil);
		[self reloadSpecifiers];
	}
	else
	{
		UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"Uninstalling the persistence helper will revert this app back to it's original state, you will however no longer be able to persistently refresh the TrollStore app registrations. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
		[uninstallWarningAlert addAction:cancelAction];

		UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
		{
			spawnRoot(rootHelperPath(), @[@"uninstall-persistence-helper"], nil, nil);
			exit(0);
		}];
		[uninstallWarningAlert addAction:continueAction];

		[TSPresentationDelegate presentViewController:uninstallWarningAlert animated:YES completion:nil];
	}
}

- (void)handleUninstallation
{
	if([self isTrollStore])
	{
		exit(0);
	}
	else
	{
		[self reloadSpecifiers];
	}
}

- (NSMutableArray*)argsForUninstallingTrollStore
{
	return @[@"uninstall-trollstore"].mutableCopy;
}

- (void)uninstallTrollStorePressed
{
	UIAlertController* uninstallAlert = [UIAlertController alertControllerWithTitle:@"Uninstall" message:@"You are about to uninstall TrollStore, do you want to preserve the apps installed by it?" preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* uninstallAllAction = [UIAlertAction actionWithTitle:@"Uninstall TrollStore, Uninstall Apps" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		NSMutableArray* args = [self argsForUninstallingTrollStore];
		spawnRoot(rootHelperPath(), args, nil, nil);
		[self handleUninstallation];
	}];
	[uninstallAlert addAction:uninstallAllAction];

	UIAlertAction* preserveAppsAction = [UIAlertAction actionWithTitle:@"Uninstall TrollStore, Preserve Apps" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		NSMutableArray* args = [self argsForUninstallingTrollStore];
		[args addObject:@"preserve-apps"];
		spawnRoot(rootHelperPath(), args, nil, nil);
		[self handleUninstallation];
	}];
	[uninstallAlert addAction:preserveAppsAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[uninstallAlert addAction:cancelAction];

	[TSPresentationDelegate presentViewController:uninstallAlert animated:YES completion:nil];
}

@end