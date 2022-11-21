#import <Foundation/Foundation.h>
#import "TSAppDelegate.h"
#import "TSUtil.h"

NSUserDefaults* trollStoreUserDefaults(void)
{
	return [[NSUserDefaults alloc] initWithSuiteName:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.opa334.TrollStore.plist"]];
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		chineseWifiFixup();
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSAppDelegate.class));
	}
}
