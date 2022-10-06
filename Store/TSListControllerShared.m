#import "TSListControllerShared.h"
#import "TSUtil.h"
#import "../Helper/Shared.h"

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

			doHandler(tarTmpPath);
		}
	}];

	[downloadTask resume];
}

- (void)_updateOrInstallTrollStore:(BOOL)update
{
	if(update)
	{
		[self startActivity:@"Updating TrollStore"];
	}
	else
	{
		[self startActivity:@"Installing TrollStore"];
	}

	[self downloadTrollStoreAndDo:^(NSString* tmpTarPath)
	{
		int ret = spawnRoot(helperPath(), @[@"install-trollstore", tmpTarPath], nil, nil);
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
					[self stopActivityWithCompletion:^
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
				[self stopActivityWithCompletion:^
				{
					UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error installing TrollStore: trollstorehelper returned %d", ret] preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
					[errorAlert addAction:closeAction];
					[self presentViewController:errorAlert animated:YES completion:nil];
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

- (void)refreshAppRegistrationsPressed
{
	[self startActivity:@"Refreshing"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		spawnRoot(helperPath(), @[@"refresh"], nil, nil);
		respring();

		dispatch_async(dispatch_get_main_queue(), ^
		{
			[self stopActivityWithCompletion:nil];
		});
	});
}

- (void)uninstallPersistenceHelperPressed
{
	if([self isTrollStore])
	{
		spawnRoot(helperPath(), @[@"uninstall-persistence-helper"], nil, nil);
		[self reloadSpecifiers];
	}
	else
	{
		UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"Uninstalling the persistence helper will revert this app back to it's original state, you will however no longer be able to persistently refresh the TrollStore app registrations. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
		[uninstallWarningAlert addAction:cancelAction];

		UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
		{
			spawnRoot(helperPath(), @[@"uninstall-persistence-helper"], nil, nil);
			exit(0);
		}];
		[uninstallWarningAlert addAction:continueAction];

		[self presentViewController:uninstallWarningAlert animated:YES completion:nil];
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

- (void)uninstallTrollStorePressed
{
	UIAlertController* uninstallWarningAlert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"About to uninstall TrollStore and all of the apps installed by it. Continue?" preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[uninstallWarningAlert addAction:cancelAction];

	UIAlertAction* continueAction = [UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		spawnRoot(helperPath(), @[@"uninstall-trollstore"], nil, nil);
		[self handleUninstallation];
	}];
	[uninstallWarningAlert addAction:continueAction];

	[self presentViewController:uninstallWarningAlert animated:YES completion:nil];
}

@end