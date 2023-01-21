#import "TSSettingsAdvancedListController.h"
#import <Preferences/PSSpecifier.h>

extern NSUserDefaults* trollStoreUserDefaults();
@interface PSSpecifier ()
@property (nonatomic,retain) NSArray* values;
@end

@implementation TSSettingsAdvancedListController

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

		PSSpecifier* installationMethodGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		//installationMethodGroupSpecifier.name = @"Installation";
		[installationMethodGroupSpecifier setProperty:@"installd:\nInstalls applications by doing a placeholder installation through installd, fixing the permissions and then adding it to icon cache.\nAdvantage: Might be slightly more persistent then the custom method in terms of icon cache reloads.\nDisadvantage: Causes some small issues with certain applications for seemingly no reason (E.g. Watusi cannot save preferences when being installed using this method).\n\nCustom (Recommended):\nInstalls applications by manually creating a bundle using MobileContainerManager, copying the app into it and adding it to icon cache.\nAdvantage: No known issues (As opposed to the Watusi issue outlined in the installd method).\nDisadvantage: Might be slightly less persistent then the installd method in terms of icon cache reloads.\n\nNOTE: In cases where installd is selected but the placeholder installation fails, TrollStore automatically falls back to using the Custom method." forKey:@"footerText"];
		[_specifiers addObject:installationMethodGroupSpecifier];

		PSSpecifier* installationMethodSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installation Method"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
		[installationMethodSpecifier setProperty:@YES forKey:@"enabled"];
		installationMethodSpecifier.identifier = @"installationMethodLabel";
		[_specifiers addObject:installationMethodSpecifier];

		PSSpecifier* installationMethodSegmentSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installation Method Segment"
											target:self
											set:@selector(setPreferenceValue:specifier:)
											get:@selector(readPreferenceValue:)
											detail:nil
											cell:PSSegmentCell
											edit:nil];
		[installationMethodSegmentSpecifier setProperty:@YES forKey:@"enabled"];
		installationMethodSegmentSpecifier.identifier = @"installationMethodSegment";
		[installationMethodSegmentSpecifier setProperty:@"com.opa334.TrollStore" forKey:@"defaults"];
		[installationMethodSegmentSpecifier setProperty:@"installationMethod" forKey:@"key"];
		installationMethodSegmentSpecifier.values = @[@0, @1];
		installationMethodSegmentSpecifier.titleDictionary = @{@0 : @"installd", @1 : @"Custom"};
		[installationMethodSegmentSpecifier setProperty:@1 forKey:@"default"];
		[_specifiers addObject:installationMethodSegmentSpecifier];

		PSSpecifier* uninstallationMethodGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		//uninstallationMethodGroupSpecifier.name = @"Uninstallation";
		[uninstallationMethodGroupSpecifier setProperty:@"installd (Recommended):\nUninstalls applications using the same API that SpringBoard uses when uninstalling them from the home screen.\n\nCustom:\nUninstalls applications by removing them from icon cache and then deleting their application and data bundles directly.\n\nNOTE: In cases where installd is selected but the stock uninstallation fails, TrollStore automatically falls back to using the Custom method." forKey:@"footerText"];
		[_specifiers addObject:uninstallationMethodGroupSpecifier];

		PSSpecifier* uninstallationMethodSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Uninstallation Method"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
		[uninstallationMethodSpecifier setProperty:@YES forKey:@"enabled"];
		uninstallationMethodSpecifier.identifier = @"uninstallationMethodLabel";
		[_specifiers addObject:uninstallationMethodSpecifier];

		PSSpecifier* uninstallationMethodSegmentSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installation Method Segment"
											target:self
											set:@selector(setPreferenceValue:specifier:)
											get:@selector(readPreferenceValue:)
											detail:nil
											cell:PSSegmentCell
											edit:nil];
		[uninstallationMethodSegmentSpecifier setProperty:@YES forKey:@"enabled"];
		uninstallationMethodSegmentSpecifier.identifier = @"uninstallationMethodSegment";
		[uninstallationMethodSegmentSpecifier setProperty:@"com.opa334.TrollStore" forKey:@"defaults"];
		[uninstallationMethodSegmentSpecifier setProperty:@"uninstallationMethod" forKey:@"key"];
		uninstallationMethodSegmentSpecifier.values = @[@0, @1];
		uninstallationMethodSegmentSpecifier.titleDictionary = @{@0 : @"installd", @1 : @"Custom"};
		[uninstallationMethodSegmentSpecifier setProperty:@0 forKey:@"default"];
		[_specifiers addObject:uninstallationMethodSegmentSpecifier];
	}

	[(UINavigationItem *)self.navigationItem setTitle:@"Advanced"];
	return _specifiers;
}

- (void)setPreferenceValue:(NSObject*)value specifier:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	[tsDefaults setObject:value forKey:[specifier propertyForKey:@"key"]];
}

- (NSObject*)readPreferenceValue:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	NSObject* toReturn = [tsDefaults objectForKey:[specifier propertyForKey:@"key"]];
	if(!toReturn)
	{
		toReturn = [specifier propertyForKey:@"default"];
	}
	return toReturn;
}

@end