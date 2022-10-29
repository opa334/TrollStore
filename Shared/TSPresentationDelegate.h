#import <UIKit/UIKit.h>

@interface TSPresentationDelegate : NSObject
@property (class) UIViewController* presentationViewController;
@property (class) UIAlertController* activityController;
+ (void)startActivity:(NSString*)activity withCancelHandler:(void (^)(void))cancelHandler;
+ (void)startActivity:(NSString*)activity;
+ (void)stopActivityWithCompletion:(void (^)(void))completion;
+ (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
@end