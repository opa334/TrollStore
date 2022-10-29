//
//  TSIPAInfo.h
//  IPAInfo
//
//  Created by Lars Fröder on 22.10.22.
//

#import <Foundation/Foundation.h>
#import <libarchive/archive.h>
#import <libarchive/archive_entry.h>
@import UIKit;

@interface TSAppInfo : NSObject
{
	NSString* _path;
	BOOL _isArchive;
	struct archive* _archive;
	
	NSString* _cachedAppBundleName;
	NSString* _cachedRegistrationState;
	NSDictionary* _cachedInfoDictionary;
	NSDictionary* _cachedInfoDictionariesByPluginSubpaths;
	NSDictionary* _cachedEntitlementsByBinarySubpaths;
	UIImage* _cachedPreviewIcon;
	int64_t _cachedSize;
}

- (instancetype)initWithIPAPath:(NSString*)ipaPath;
- (instancetype)initWithAppBundlePath:(NSString*)bundlePath;
- (NSError*)determineAppBundleName;
- (NSError*)loadInfoDictionary;
- (NSError*)loadEntitlements;
- (NSError*)loadPreviewIcon;

- (NSError*)sync_loadBasicInfo;
- (NSError*)sync_loadInfo;

- (void)loadBasicInfoWithCompletion:(void (^)(NSError*))completionHandler;
- (void)loadInfoWithCompletion:(void (^)(NSError*))completionHandler;

- (NSString*)displayName;
- (NSString*)bundleIdentifier;
- (NSString*)versionString;
- (NSString*)sizeString;
- (NSString*)bundlePath;
- (NSString*)registrationState;

- (UIImage*)iconForSize:(CGSize)size;

- (NSAttributedString*)detailedInfoTitle;
- (NSAttributedString*)detailedInfoDescription;
//- (UIImage*)image;
- (void)log;

@end
