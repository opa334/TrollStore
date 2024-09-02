#import <Foundation/Foundation.h>
#import "TSAppDelegate.h"
#import "TSUtil.h"

NSUserDefaults* trollStoreUserDefaults(void)
{
	return [[NSUserDefaults alloc] initWithSuiteName:[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", APP_ID]]];
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		chineseWifiFixup();
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSAppDelegate.class));
	}
}
