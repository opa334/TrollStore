#import <Foundation/Foundation.h>
#import "TSI2AppDelegate.h"
#import "TSI2SceneDelegate.h"
#import <objc/runtime.h>

extern int rootHelperMain(int argc, char *argv[], char *envp[]);

void classFixup(void)
{
	Class newClass = objc_allocateClassPair([TSI2SceneDelegate class], "WWDC.SceneDelegate", 0);
	objc_registerClassPair(newClass);
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if(getuid() == 0)
		{
			// I got this idea while taking a shit
			// Don't judge
			return rootHelperMain(argc, argv, envp);
		}
		else
		{
			classFixup();
			return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSI2AppDelegate.class));
		}
	}
}
