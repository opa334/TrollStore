#import "TSDonateListController.h"
#import <Preferences/PSSpecifier.h>

@implementation TSDonateListController


- (void)donateToAlfiePressed
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://ko-fi.com/alfiecg_dev"] options:@{} completionHandler:^(BOOL success){}];
}

- (void)donateToOpaPressed
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=opa334@protonmail.com&item_name=TrollStore"] options:@{} completionHandler:^(BOOL success){}];
}

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];
		
		PSSpecifier* alfieGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		alfieGroupSpecifier.name = @"Alfie";
		[alfieGroupSpecifier setProperty:@"Alfie found the new CoreTrust bug (CVE-2023-41991) via patchdiffing, produced a POC binary and worked on automatically applying it with the help of the ChOma library, while also contributing to said library." forKey:@"footerText"];
		[_specifiers addObject:alfieGroupSpecifier];

		PSSpecifier* alfieDonateSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Donate to alfiecg_dev"
									target:self
									set:nil
									get:nil
									detail:nil
									cell:PSButtonCell
									edit:nil];
		alfieDonateSpecifier.identifier = @"donateToAlfie";
		[alfieDonateSpecifier setProperty:@YES forKey:@"enabled"];
		alfieDonateSpecifier.buttonAction = @selector(donateToAlfiePressed);
		[_specifiers addObject:alfieDonateSpecifier];

		PSSpecifier* opaGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		opaGroupSpecifier.name = @"Opa";
		[opaGroupSpecifier setProperty:@"Opa developed the ChOma library, helped with automating the bug using it and integrated it into TrollStore." forKey:@"footerText"];
		[_specifiers addObject:opaGroupSpecifier];

		PSSpecifier* opaDonateSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Donate to opa334"
									target:self
									set:nil
									get:nil
									detail:nil
									cell:PSButtonCell
									edit:nil];
		opaDonateSpecifier.identifier = @"donateToOpa";
		[opaDonateSpecifier setProperty:@YES forKey:@"enabled"];
		opaDonateSpecifier.buttonAction = @selector(donateToOpaPressed);
		[_specifiers addObject:opaDonateSpecifier];
	}
	[(UINavigationItem *)self.navigationItem setTitle:@"Donate"];
	return _specifiers;
}

@end