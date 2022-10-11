#import <UIKit/UIKit.h>

@interface TSHAppDelegateNoScene : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *rootViewController;
@end