#import "TSPresentationDelegate.h"

@implementation TSPresentationDelegate

static UIViewController* g_presentationViewController;
static UIAlertController* g_activityController;

+ (UIViewController*)presentationViewController
{
	return g_presentationViewController;
}

+ (void)setPresentationViewController:(UIViewController*)vc
{
	g_presentationViewController = vc;
}

+ (UIAlertController*)activityController
{
	return g_activityController;
}

+ (void)setActivityController:(UIAlertController*)ac
{
	g_activityController = ac;
}

+ (void)startActivity:(NSString*)activity withCancelHandler:(void (^)(void))cancelHandler
{
	if(self.activityController)
	{
		self.activityController.title = activity;
	}
	else
	{
		self.activityController = [UIAlertController alertControllerWithTitle:activity message:@"" preferredStyle:UIAlertControllerStyleAlert];
		UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(5,5,50,50)];
		activityIndicator.hidesWhenStopped = YES;
		activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
		[activityIndicator startAnimating];
		[self.activityController.view addSubview:activityIndicator];

		if(cancelHandler)
		{
			UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action)
			{
				self.activityController = nil;
				cancelHandler();
			}];
			[self.activityController addAction:cancelAction];
		}

		[self presentViewController:self.activityController animated:YES completion:nil];
	}
}

+ (void)startActivity:(NSString*)activity
{
	[self startActivity:activity withCancelHandler:nil];
}

+ (void)stopActivityWithCompletion:(void (^)(void))completionBlock
{
	if(!self.activityController) return;

	[self.activityController dismissViewControllerAnimated:YES completion:^
	{
		self.activityController = nil;
		if(completionBlock) completionBlock();
	}];
}

+ (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completionBlock
{
	[self.presentationViewController presentViewController:viewControllerToPresent animated:flag completion:completionBlock];
}

@end