#import "TSI2RootViewController.h"
#import "../../Helper/Shared.h"
#import "../../Store/TSUtil.h"

@implementation TSI2RootViewController

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

		BOOL isInstalled = trollStoreAppPath();

		PSSpecifier* utilitiesGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		[_specifiers addObject:utilitiesGroupSpecifier];
		[utilitiesGroupSpecifier setProperty:@"Based on the Fugu15 install method\nMassive shoutouts to @LinusHenze\n\n© 2022 Lars Fröder (opa334)" forKey:@"footerText"];

		if(isInstalled)
		{
			PSSpecifier* alreadyInstalledSpecifier = [PSSpecifier preferenceSpecifierNamed:@"TrollStore already installed"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSStaticTextCell
												edit:nil];
			alreadyInstalledSpecifier.identifier = @"alreadyInstalled";
			[alreadyInstalledSpecifier setProperty:@YES forKey:@"enabled"];
			[_specifiers addObject:alreadyInstalledSpecifier];
		}
		else
		{
			PSSpecifier* installTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Install TrollStore"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			installTrollStoreSpecifier.identifier = @"installTrollStore";
			[installTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
			installTrollStoreSpecifier.buttonAction = @selector(installTrollStorePressed);
			[_specifiers addObject:installTrollStoreSpecifier];
		}
	}
	
	[(UINavigationItem *)self.navigationItem setTitle:@"TrollStore Installer 2"];
	return _specifiers;
}

extern NSString* safe_getExecutablePath();
- (void)installTrollStorePressed
{
	[self startActivity:@"Installing TrollStore"];

	[self downloadTrollStoreAndDo:^(NSString* tmpTarPath)
	{
		int ret = spawnRoot(safe_getExecutablePath(), @[@"install-trollstore", tmpTarPath], nil, nil);
		[[NSFileManager defaultManager] removeItemAtPath:tmpTarPath error:nil];
		if(ret == 0)
		{
			respring();

			if([self isTrollStore])
			{
				exit(0);
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^
				{
					[self stopActivityWithCompletion:^
					{
						[self reloadSpecifiers];
					}];
				});
			}
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self stopActivityWithCompletion:^
				{
					UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error installing TrollStore: trollstorehelper returned %d", ret] preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
					[errorAlert addAction:closeAction];
					[self presentViewController:errorAlert animated:YES completion:nil];
				}];
			});
		}
	}];
}

@end
