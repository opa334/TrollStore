#import <Foundation/Foundation.h>
#import "TSHAppDelegateNoScene.h"
#import "TSHAppDelegateWithScene.h"
#import "TSHSceneDelegate.h"
#import <TSUtil.h>
#import <objc/runtime.h>

BOOL sceneDelegateFix(void)
{
	NSString* sceneDelegateClassName = nil;
	
	NSDictionary* UIApplicationSceneManifest = [NSBundle.mainBundle objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
	if(UIApplicationSceneManifest && [UIApplicationSceneManifest isKindOfClass:NSDictionary.class])
	{
		NSDictionary* UISceneConfiguration = UIApplicationSceneManifest[@"UISceneConfigurations"];
		if(UISceneConfiguration && [UISceneConfiguration isKindOfClass:NSDictionary.class])
		{
			NSArray* UIWindowSceneSessionRoleApplication = UISceneConfiguration[@"UIWindowSceneSessionRoleApplication"];
			if(UIWindowSceneSessionRoleApplication && [UIWindowSceneSessionRoleApplication isKindOfClass:NSArray.class])
			{
				NSDictionary* sceneToUse = nil;
				if(UIWindowSceneSessionRoleApplication.count > 1)
				{
					for(NSDictionary* scene in UIWindowSceneSessionRoleApplication)
					{
						if([scene isKindOfClass:NSDictionary.class])
						{
							NSString* UISceneConfigurationName = scene[@"UISceneConfigurationName"];
							if([UISceneConfigurationName isKindOfClass:NSString.class])
							{
								if([UISceneConfigurationName isEqualToString:@"Default Configuration"])
								{
									sceneToUse = scene;
									break;
								}
							}
						}
					}

					if(!sceneToUse)
					{
						sceneToUse = UIWindowSceneSessionRoleApplication.firstObject;
					}
				}
				else
				{
					sceneToUse = UIWindowSceneSessionRoleApplication.firstObject;
				}

				if(sceneToUse && [sceneToUse isKindOfClass:NSDictionary.class])
				{
					sceneDelegateClassName = sceneToUse[@"UISceneDelegateClassName"];
				}
			}
		}
	}

	if(sceneDelegateClassName && [sceneDelegateClassName isKindOfClass:NSString.class])
	{
		Class newClass = objc_allocateClassPair([TSHSceneDelegate class], sceneDelegateClassName.UTF8String, 0);
		objc_registerClassPair(newClass);
		return YES;
	}

	return NO;
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		#ifdef EMBEDDED_ROOT_HELPER
		extern int rootHelperMain(int argc, char *argv[], char *envp[]);
		if(getuid() == 0)
		{
			// I got this idea while taking a dump
			// Don't judge
			return rootHelperMain(argc, argv, envp);
		}
		#endif

		chineseWifiFixup();
		if(sceneDelegateFix())
		{
			return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSHAppDelegateWithScene.class));
		}
		else
		{
			return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSHAppDelegateNoScene.class));
		}
	}
}
