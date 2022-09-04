#import "TSSceneDelegate.h"
#import "TSRootViewController.h"
#import "TSUtil.h"
#import "TSApplicationsManager.h"

@implementation TSSceneDelegate

- (void)doIPAInstall:(NSString*)ipaPath scene:(UIWindowScene*)scene force:(BOOL)force completion:(void (^)(void))completion
{
    UIWindow* keyWindow = nil;
    for(UIWindow* window in scene.windows)
    {
        if(window.isKeyWindow)
        {
            keyWindow = window;
            break;
        }
    }

    UIAlertController* infoAlert = [UIAlertController alertControllerWithTitle:@"Installing" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(5,5,50,50)];
    activityIndicator.hidesWhenStopped = YES;
    activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
    [activityIndicator startAnimating];
    [infoAlert.view addSubview:activityIndicator];

    [keyWindow.rootViewController presentViewController:infoAlert animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        // Install IPA
        int ret = [[TSApplicationsManager sharedInstance] installIpa:ipaPath force:force];
        NSError* error = [[TSApplicationsManager sharedInstance] errorForCode:ret];

        NSLog(@"installed app! ret:%d, error: %@", ret, error);
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [infoAlert dismissViewControllerAnimated:YES completion:^
            {
                if(ret != 0)
                {
                    UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Install Error %d", ret] message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
                    {
                        if(ret == 171)
                        {
                            completion();
                        }
                    }];
                    if(ret == 171)
                    {
                        UIAlertAction* forceInstallAction = [UIAlertAction actionWithTitle:@"Force Installation" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
                        {
                            [self doIPAInstall:ipaPath scene:scene force:YES completion:completion];
                        }];
                        [errorAlert addAction:forceInstallAction];
                    }
                    [errorAlert addAction:closeAction];

                    [keyWindow.rootViewController presentViewController:errorAlert animated:YES completion:nil];
                }

                if(ret != 171)
                {
                    completion();
                }
            }];
        });
    });
}

- (void)handleURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts scene:(UIWindowScene*)scene
{
    for(UIOpenURLContext* context in URLContexts)
    {
        NSLog(@"openURLContexts %@", context.URL);
        NSURL* url = context.URL;
        if (url != nil && [url isFileURL]) {
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
            
            if ([url.pathExtension isEqualToString:@"ipa"])
            {
                [self doIPAInstall:url.path scene:(UIWindowScene*)scene force:NO completion:^{
                    doneBlock(NO);
                }];
            }
            else if([url.pathExtension isEqualToString:@"tar"])
            {
                // Update TrollStore itself
                NSLog(@"Updating TrollStore...");
                int ret = spawnRoot(helperPath(), @[@"install-trollstore", url.path]);
                doneBlock(ret == 0);
                NSLog(@"Updated TrollStore!");
            }
        }
    }
}


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
    NSLog(@"scene:%@ willConnectToSession:%@ options:%@", scene, session, connectionOptions);
    UIWindowScene* windowScene = (UIWindowScene*)scene;
    _window = [[UIWindow alloc] initWithWindowScene:windowScene];
    _rootViewController = [[TSRootViewController alloc] init];
    _window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];

    if(connectionOptions.URLContexts.count)
    {
        [self handleURLContexts:connectionOptions.URLContexts scene:(UIWindowScene*)scene];
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
    NSLog(@"scene:%@ openURLContexts:%@", scene, URLContexts);
    [self handleURLContexts:URLContexts scene:(UIWindowScene*)scene];
}

@end