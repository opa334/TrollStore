#import <Foundation/Foundation.h>
#import "TSPHAppDelegate.h"

int main(int argc, char *argv[]) {
	@autoreleasepool {
		NSBundle* mcmBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/MobileContainerManager.framework"];
        [mcmBundle load];
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSPHAppDelegate.class));
	}
}
