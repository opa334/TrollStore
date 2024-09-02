#import "TSSceneDelegate.h"
#import "TSRootViewController.h"
#import "TSUtil.h"
#import "TSApplicationsManager.h"
#import "TSInstallationController.h"
#import <TSPresentationDelegate.h>

@implementation TSSceneDelegate

- (void)handleURLContexts:(NSSet<UIOpenURLContext*>*)URLContexts scene:(UIWindowScene*)scene
{
	for(UIOpenURLContext* context in URLContexts)
	{
		NSURL* url = context.URL;

		if(url)
		{
			if([url isFileURL])
			{
				[url startAccessingSecurityScopedResource];
				void (^doneBlock)(BOOL) = ^(BOOL shouldExit)
				{
					[url stopAccessingSecurityScopedResource];
					[[NSFileManager defaultManager] removeItemAtURL:url error:nil];

					if(shouldExit)
					{
						NSLog(@"Respring + Exit");
						respring();
						exit(0);
					}
				};
				
				if ([url.pathExtension.lowercaseString isEqualToString:@"ipa"] || [url.pathExtension.lowercaseString isEqualToString:@"tipa"])
				{
					[TSInstallationController presentInstallationAlertIfEnabledForFile:url.path isRemoteInstall:NO completion:^(BOOL success, NSError* error){
						doneBlock(NO);
					}];
				}
				else if([url.pathExtension.lowercaseString isEqualToString:@"tar"])
				{
					// Update TrollStore itself
					NSLog(@"Updating TrollStore...");
					int ret = spawnRoot(rootHelperPath(), @[@"install-trollstore", url.path], nil, nil);
					doneBlock(ret == 0);
					NSLog(@"Updated TrollStore!");
				}
			}
			else if([url.scheme isEqualToString:@"apple-magnifier"])
			{
				NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
				if([components.host isEqualToString:@"install"])
				{
					NSString* URLStringToInstall;

					for(NSURLQueryItem* queryItem in components.queryItems)
					{
						if([queryItem.name isEqualToString:@"url"])
						{
							URLStringToInstall = queryItem.value;
							break;
						}
					}

					if(URLStringToInstall && [URLStringToInstall isKindOfClass:NSString.class])
					{
						NSURL* URLToInstall = [NSURL URLWithString:URLStringToInstall];
						[TSInstallationController handleAppInstallFromRemoteURL:URLToInstall completion:nil];
					}
				}
				else if([components.host isEqualToString:@"enable-jit"])
				{
					NSString* BundleIDToEnableJIT;

					for(NSURLQueryItem* queryItem in components.queryItems)
					{
						if([queryItem.name isEqualToString:@"bundle-id"])
						{
							BundleIDToEnableJIT = queryItem.value;
							break;
						}
					}

					if(BundleIDToEnableJIT && [BundleIDToEnableJIT isKindOfClass:NSString.class])
					{
						dispatch_async(dispatch_get_main_queue(), ^
	{
							[self handleEnableJITForBundleID:BundleIDToEnableJIT];
						});
					}
				}
			}
		}
	}
}

- (void)handleEnableJITForBundleID:(NSString *)appId
{
	TSApplicationsManager* appsManager = [TSApplicationsManager sharedInstance];

	BOOL didOpen = [appsManager openApplicationWithBundleID:appId];

	// if we failed to open the app, show an alert
	if(!didOpen)
	{
		NSString* failMessage = @"";
		// we don't have TSAppInfo here so we cannot check the registration state

		NSString* failTitle = [NSString stringWithFormat:@"Failed to open %@", appId];
		UIAlertController* didFailController = [UIAlertController alertControllerWithTitle:failTitle message:failMessage preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

		[didFailController addAction:cancelAction];
		[TSPresentationDelegate presentViewController:didFailController animated:YES completion:nil];
	}
	else
	{
		int ret = [appsManager enableJITForBundleID:appId];
		if (ret != 0)
		{
			UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error enabling JIT: trollstorehelper returned %d", ret] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
			[errorAlert addAction:closeAction];
			[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
		}
	}
}

// We want to auto install ldid if either it doesn't exist
// or if it's the one from an old TrollStore version that's no longer supported
- (void)handleLdidCheck
{
#ifndef TROLLSTORE_LITE
	//if (@available(iOS 16, *)) {} else {
		NSString* tsAppPath = [NSBundle mainBundle].bundlePath;

		NSString* ldidPath = [tsAppPath stringByAppendingPathComponent:@"ldid"];
		NSString* ldidVersionPath = [tsAppPath stringByAppendingPathComponent:@"ldid.version"];

		if(![[NSFileManager defaultManager] fileExistsAtPath:ldidPath] || ![[NSFileManager defaultManager] fileExistsAtPath:ldidVersionPath])
		{
			[TSInstallationController installLdid];
		}
	//}
#endif
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
	// Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
	// If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
	// This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
	
	UIWindowScene* windowScene = (UIWindowScene*)scene;
	_window = [[UIWindow alloc] initWithWindowScene:windowScene];
	_rootViewController = [[TSRootViewController alloc] init];
	_window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];

	if(connectionOptions.URLContexts.count)
	{
		[self handleURLContexts:connectionOptions.URLContexts scene:(UIWindowScene*)scene];
	}
	else
	{
		[self handleLdidCheck];
	}
}


- (void)sceneDidDisconnect:(UIScene *)scene {
	// Called as the scene is being released by the system.
	// This occurs shortly after the scene enters the background, or when its session is discarded.
	// Release any resources associated with this scene that can be re-created the next time the scene connects.
	// The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
	// Called when the scene has moved from an inactive state to an active state.
	// Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
	// Called when the scene will move from an active state to an inactive state.
	// This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
	// Called as the scene transitions from the background to the foreground.
	// Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
	// Called as the scene transitions from the foreground to the background.
	// Use this method to save data, release shared resources, and store enough scene-specific state information
	// to restore the scene back to its current state.
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
	[self handleURLContexts:URLContexts scene:(UIWindowScene*)scene];
}

@end