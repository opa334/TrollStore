#import "TSSceneDelegate.h"
#import "TSRootViewController.h"
#import "TSUtil.h"
#import "TSApplicationsManager.h"

@implementation TSSceneDelegate

- (void)handleURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    for(UIOpenURLContext* context in URLContexts)
    {
        NSLog(@"openURLContexts %@", context.URL);
        NSURL* url = context.URL;
        if (url != nil && [url isFileURL]) {
            BOOL shouldExit = NO;
            
            [url startAccessingSecurityScopedResource];
            NSURL* tmpCopyURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:url.lastPathComponent]];
            
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:tmpCopyURL error:nil];
            
            if ([url.pathExtension isEqualToString:@"ipa"]) {
                // Install IPA
                NSError* error;
                int ret = [[TSApplicationsManager sharedInstance] installIpa:tmpCopyURL.path error:&error];
                NSLog(@"installed app! ret:%d, error: %@", ret, error);
                
            }
            else if([url.pathExtension isEqualToString:@"tar"])
            {
                // Update TrollStore itself
                NSLog(@"Updating TrollStore...");
                int ret = spawnRoot(helperPath(), @[@"install-trollstore", tmpCopyURL.path]);
                if(ret == 0) shouldExit = YES;
                NSLog(@"Updated TrollStore!");
            }
            
            [[NSFileManager defaultManager] removeItemAtURL:tmpCopyURL error:nil];
            [url stopAccessingSecurityScopedResource];
            
            if(shouldExit)
            {
                NSLog(@"Respring + Exit");
                respring();
                exit(0);
            }
        }
    }
}


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
    NSLog(@"scene:%@ willConnectToSession:%@ options:%@", scene, session, connectionOptions);
    if(connectionOptions.URLContexts.count)
    {
        [self handleURLContexts:connectionOptions.URLContexts];
    }

    UIWindowScene* windowScene = (UIWindowScene*)scene;
    _window = [[UIWindow alloc] initWithWindowScene:windowScene];
    _rootViewController = [[TSRootViewController alloc] init];
    _window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];
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
    [self handleURLContexts:URLContexts];
}

@end