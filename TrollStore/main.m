#import <Foundation/Foundation.h>
#import "TSAppDelegate.h"
#import "TSUtil.h"

int main(int argc, char *argv[]) {
	@autoreleasepool {
		chineseWifiFixup();
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(TSAppDelegate.class));
	}
}
