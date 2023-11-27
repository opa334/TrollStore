#import "TSAppInfo.h"
#import "TSCommonTCCServiceNames.h"
#import <TSUtil.h>

extern CGImageRef LICreateIconForImage(CGImageRef image, int variant, int precomposed);
extern UIImage* imageWithSize(UIImage* image, CGSize size);

@implementation TSAppInfo

- (instancetype)initWithIPAPath:(NSString*)ipaPath
{
	self = [super init];
	
	if(self)
	{
		_path = ipaPath;
		_isArchive = YES;
		_archive = nil;
	}
	
	return self;
}

- (instancetype)initWithAppBundlePath:(NSString*)bundlePath
{
	self = [super init];
	
	if(self)
	{
		_path = bundlePath;
		_isArchive = NO;
		_archive = nil;
	}
	
	return self;
}

- (void)dealloc
{
	[self closeArchive];
}

- (void)enumerateArchive:(void (^)(struct archive_entry* entry, BOOL* stop))enumerateBlock
{
	[self openArchive];

	struct archive_entry *entry;
	int r;
	for (;;)
	{
		r = archive_read_next_header(_archive, &entry);
		if (r == ARCHIVE_EOF)
			break;
		if (r < ARCHIVE_OK)
			fprintf(stderr, "%s\n", archive_error_string(_archive));
		if (r < ARCHIVE_WARN)
			return;
		
		BOOL stop = NO;
		enumerateBlock(entry, &stop);
		if(stop) break;
	}
}

- (struct archive_entry*)archiveEntryForSubpath:(NSString*)subpath
{
	__block struct archive_entry* outEntry = nil;
	[self enumerateArchive:^(struct archive_entry *entry, BOOL *stop) {
		NSString* currentSubpath = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
		if([currentSubpath isEqualToString:subpath])
		{
			outEntry = entry;
			*stop = YES;
		}
	}];
	return outEntry;
}

- (NSError*)determineAppBundleName
{
	NSError* outError;

	if(!_cachedAppBundleName)
	{
		if(_isArchive)
		{
			[self enumerateArchive:^(struct archive_entry *entry, BOOL *stop)
			{
				NSString* currentSubpath = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
				if(currentSubpath.pathComponents.count == 3)
				{
					if([currentSubpath.pathComponents[0] isEqualToString:@"Payload"] && [currentSubpath.pathComponents[1].pathExtension isEqualToString:@"app"])
					{
						self->_cachedAppBundleName = currentSubpath.pathComponents[1];
						*stop = YES;
					}
				}
			}];

			if(!_cachedAppBundleName)
			{
				NSString* errorDescription = @"Unable to locate app bundle inside the .IPA archive.";
				outError = [NSError errorWithDomain:TrollStoreErrorDomain code:301 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
			}
		}
	}

	return outError;
}

- (NSError*)loadInfoDictionary
{
	if(_isArchive && _cachedAppBundleName)
	{
		NSString* mainInfoPlistPath = [NSString stringWithFormat:@"Payload/%@/Info.plist", _cachedAppBundleName];
		struct archive_entry* infoDictEntry = [self archiveEntryForSubpath:mainInfoPlistPath];
		if(infoDictEntry)
		{
			size_t size = archive_entry_size(infoDictEntry);
			void* buf = malloc(size);
			size_t read = archive_read_data(_archive, buf, size);
			
			if(read == size)
			{
				NSData* infoPlistData = [NSData dataWithBytes:buf length:size];
				_cachedInfoDictionary = [NSPropertyListSerialization propertyListWithData:infoPlistData options:NSPropertyListImmutable format:nil error:nil];
			}
			free(buf);
		}
		
		__block NSMutableDictionary* pluginInfoDictionaries = [NSMutableDictionary new];
		
		[self enumerateArchive:^(struct archive_entry *entry, BOOL *stop) {
			NSString* currentSubpath = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
			if([currentSubpath isEqualToString:mainInfoPlistPath]) return;
			
			if([currentSubpath.lastPathComponent isEqualToString:@"Info.plist"] && currentSubpath.pathComponents.count == 5)
			{
				if([currentSubpath.pathComponents[2] isEqualToString:@"PlugIns"])
				{
					size_t size = archive_entry_size(entry);
					void* buf = malloc(size);
					size_t read = archive_read_data(self->_archive, buf, size);
					
					if(read == size)
					{
						NSData* infoPlistData = [NSData dataWithBytes:buf length:size];
						NSDictionary* pluginPlist = [NSPropertyListSerialization propertyListWithData:infoPlistData options:NSPropertyListImmutable format:nil error:nil];
						pluginInfoDictionaries[currentSubpath.stringByDeletingLastPathComponent] = pluginPlist;
					}
					free(buf);
				}
			}
		}];
		
		_cachedInfoDictionariesByPluginSubpaths = pluginInfoDictionaries.copy;
	}
	else
	{
		NSString* mainInfoPlistPath = [_path stringByAppendingPathComponent:@"Info.plist"];
		if([[NSFileManager defaultManager] fileExistsAtPath:mainInfoPlistPath])
		{
			_cachedInfoDictionary = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:mainInfoPlistPath] error:nil];
		}

		__block NSMutableDictionary* pluginInfoDictionaries = [NSMutableDictionary new];
		NSArray* plugIns = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[_path stringByAppendingPathComponent:@"PlugIns"] error:nil];
		for(NSString* plugIn in plugIns)
		{
			NSString* pluginSubpath = [NSString stringWithFormat:@"PlugIns/%@", plugIn];
			NSString* pluginInfoDictionaryPath = [[_path stringByAppendingPathComponent:pluginSubpath] stringByAppendingPathComponent:@"Info.plist"];
			NSDictionary* pluginInfoDictionary = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:pluginInfoDictionaryPath] error:nil];
			if(pluginInfoDictionary)
			{
				pluginInfoDictionaries[pluginSubpath] = pluginInfoDictionary;
			}
		}

		_cachedInfoDictionariesByPluginSubpaths = pluginInfoDictionaries.copy;
	}

	if(!_cachedInfoDictionary)
	{
		NSString* errorDescription = @"Unable to locate Info.plist inside app bundle.";
		return [NSError errorWithDomain:TrollStoreErrorDomain code:302 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
	}
	
	return nil;
}

- (NSError*)loadInstalledState
{
	if(!_isArchive)
	{
		NSURL* bundleURL = [NSURL fileURLWithPath:_path];
		LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForBundleURL:bundleURL];
		if(appProxy)
		{
			if(appProxy && appProxy.isInstalled)
			{
				_cachedRegistrationState = appProxy.applicationType;
			}
		}
	}
	return nil;
}

- (NSError*)loadEntitlements
{
	if(!_cachedEntitlementsByBinarySubpaths)
	{
		NSMutableDictionary* entitlementsByBinarySubpaths = [NSMutableDictionary new];

		if(_isArchive)
		{
			if(_cachedInfoDictionary)
			{
				NSString* bundleExecutable = _cachedInfoDictionary[@"CFBundleExecutable"];
				NSString* bundleExecutableSubpath = [NSString stringWithFormat:@"Payload/%@/%@", _cachedAppBundleName, bundleExecutable];
				struct archive_entry* mainBinaryEntry = [self archiveEntryForSubpath:bundleExecutableSubpath];
				if(!mainBinaryEntry)
				{
					NSString* errorDescription = @"Unable to locate main binary inside app bundle.";
					return [NSError errorWithDomain:TrollStoreErrorDomain code:303 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
				}
				
				size_t size = archive_entry_size(mainBinaryEntry);
				void* buf = malloc(size);
				size_t read = archive_read_data(_archive, buf, size);
				
				if(read == size)
				{
					NSData* binaryData = [NSData dataWithBytes:buf length:size];
					entitlementsByBinarySubpaths[bundleExecutableSubpath] = dumpEntitlementsFromBinaryData(binaryData);
				}
				free(buf);
			}
			
			[_cachedInfoDictionariesByPluginSubpaths enumerateKeysAndObjectsUsingBlock:^(NSString* pluginSubpath, NSDictionary* infoDictionary, BOOL * _Nonnull stop) {
				NSString* pluginExecutable = infoDictionary[@"CFBundleExecutable"];
				NSString* pluginExecutableSubpath = [NSString stringWithFormat:@"%@/%@", pluginSubpath, pluginExecutable];
				struct archive_entry* pluginBinaryEntry = [self archiveEntryForSubpath:pluginExecutableSubpath];
				if(!pluginBinaryEntry) return;
				
				size_t size = archive_entry_size(pluginBinaryEntry);
				void* buf = malloc(size);
				size_t read = archive_read_data(_archive, buf, size);
				
				if(read == size)
				{
					NSData* binaryData = [NSData dataWithBytes:buf length:size];
					entitlementsByBinarySubpaths[pluginExecutableSubpath] = dumpEntitlementsFromBinaryData(binaryData);
				}
				free(buf);
			}];
		}
		else
		{
			if(_cachedInfoDictionary)
			{
				NSString* bundleExecutable = _cachedInfoDictionary[@"CFBundleExecutable"];
				NSString* bundleExecutablePath = [_path stringByAppendingPathComponent:bundleExecutable];

				if(![[NSFileManager defaultManager] fileExistsAtPath:bundleExecutablePath])
				{
					NSString* errorDescription = @"Unable to locate main binary inside app bundle.";
					return [NSError errorWithDomain:TrollStoreErrorDomain code:303 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
				}

				entitlementsByBinarySubpaths[bundleExecutable] = dumpEntitlementsFromBinaryAtPath(bundleExecutablePath);
			}

			[_cachedInfoDictionariesByPluginSubpaths enumerateKeysAndObjectsUsingBlock:^(NSString* pluginSubpath, NSDictionary* infoDictionary, BOOL * _Nonnull stop) {
				NSString* pluginExecutable = infoDictionary[@"CFBundleExecutable"];
				NSString* pluginExecutableSubpath = [NSString stringWithFormat:@"%@/%@", pluginSubpath, pluginExecutable];

				NSString* pluginExecutablePath = [_path stringByAppendingPathComponent:pluginExecutableSubpath];
				entitlementsByBinarySubpaths[pluginExecutableSubpath] = dumpEntitlementsFromBinaryAtPath(pluginExecutablePath);
			}];
		}

		_cachedEntitlementsByBinarySubpaths = entitlementsByBinarySubpaths.copy;
	}
	return 0;
}

- (NSError*)loadSize
{
	_cachedSize = 0;

	if(_isArchive)
	{
		[self enumerateArchive:^(struct archive_entry* entry, BOOL* stop)
		{
			int64_t size = archive_entry_size(entry);
			_cachedSize += size;
		}];
	}
	else
	{
		NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:_path]
					     includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLFileAllocatedSizeKey,NSURLTotalFileAllocatedSizeKey]
					     options:0
					     errorHandler:nil];

		for(NSURL* itemURL in enumerator)
		{
			NSNumber* isRegularFile;
			NSError* error;
			[itemURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:&error];

			if(isRegularFile.boolValue)
			{
				NSNumber* totalFileAllocatedSize;
				[itemURL getResourceValue:&totalFileAllocatedSize forKey:NSURLTotalFileAllocatedSizeKey error:nil];
				if(totalFileAllocatedSize)
				{
					_cachedSize += totalFileAllocatedSize.integerValue;
				}
				else
				{
					NSNumber* fileAllocatedSize;
					[itemURL getResourceValue:&fileAllocatedSize forKey:NSURLFileAllocatedSizeKey error:nil];
					if(fileAllocatedSize)
					{
						_cachedSize += fileAllocatedSize.integerValue;
					}
				}
			}
		}
	}

	return nil;
}

- (NSError*)loadPreviewIcon
{
	int imageVariant;
	CGFloat screenScale = UIScreen.mainScreen.scale;

	if(screenScale >= 3.0)
	{
		imageVariant = 34;
	}
	else if(screenScale >= 2.0)
	{
		imageVariant = 17;
	}
	else
	{
		imageVariant = 4;
	}

	CGImageRef liIcon = LICreateIconForImage([[self iconForSize:CGSizeMake(29,29)] CGImage], imageVariant, 0);
	_cachedPreviewIcon = [[UIImage alloc] initWithCGImage:liIcon scale:screenScale orientation:0];;
	return nil;
}

- (int)openArchive
{
	if(_archive)
	{
		[self closeArchive];
	}
	_archive = archive_read_new();
	archive_read_support_format_all(_archive);
	archive_read_support_filter_all(_archive);
	int r = archive_read_open_filename(_archive, _path.fileSystemRepresentation, 10240);
	return r ? r : 0;
}

- (void)closeArchive
{
	if(_archive)
	{
		archive_read_close(_archive);
		archive_read_free(_archive);
		_archive = nil;
	}
}

- (NSError*)sync_loadBasicInfo
{
	NSError* e;
	
	e = [self determineAppBundleName];
	if(e) return e;
	
	e = [self loadInfoDictionary];
	if(e) return e;

	e = [self loadInstalledState];
	if(e) return e;

	return nil;
}

- (NSError*)sync_loadInfo
{
	NSError* e;

	e = [self sync_loadBasicInfo];
	if(e) return e;
	
	e = [self loadEntitlements];
	if(e) return e;

	e = [self loadSize];
	if(e) return e;

	e = [self loadPreviewIcon];
	if(e) return e;

	return nil;
}

- (void)loadBasicInfoWithCompletion:(void (^)(NSError*))completionBlock
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		if(completionBlock) completionBlock([self sync_loadBasicInfo]);
	});
}

- (void)loadInfoWithCompletion:(void (^)(NSError*))completionBlock
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		if(completionBlock) completionBlock([self sync_loadInfo]);
	});
}

- (void)enumerateAllInfoDictionaries:(void (^)(NSString* key, NSObject* value, BOOL* stop))enumerateBlock
{
	if(!enumerateBlock) return;

	__block BOOL b_stop = NO;
	
	[_cachedInfoDictionary enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSObject* value, BOOL* stop) {
		enumerateBlock(key, value, &b_stop);
		if(b_stop) *stop = YES;
	}];
	
	if(b_stop) return;
	
	[_cachedInfoDictionariesByPluginSubpaths enumerateKeysAndObjectsUsingBlock:^(NSString* pluginSubpath, NSDictionary* pluginInfoDictionary, BOOL* stop_1)
	{
		if([pluginInfoDictionary isKindOfClass:NSDictionary.class])
		{
			[pluginInfoDictionary enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSObject* value, BOOL * _Nonnull stop_2) {
				enumerateBlock(key, value, &b_stop);
				if(b_stop)
				{
					*stop_1 = YES;
					*stop_2 = YES;
				}
			}];
		}
	}];
}

- (void)enumerateAllEntitlements:(void (^)(NSString* key, NSObject* value, BOOL* stop))enumerateBlock
{
	if(!enumerateBlock) return;

	__block BOOL b_stop = NO;
	
	[_cachedEntitlementsByBinarySubpaths enumerateKeysAndObjectsUsingBlock:^(NSString* binarySubpath, NSDictionary* binaryInfoDictionary, BOOL* stop_1)
	{
		if([binaryInfoDictionary isKindOfClass:NSDictionary.class])
		{
			[binaryInfoDictionary enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSObject* value, BOOL * _Nonnull stop_2) {
				enumerateBlock(key, value, &b_stop);
				if(b_stop)
				{
					*stop_1 = YES;
					*stop_2 = YES;
				}
			}];
		}
	}];
}

- (void)enumerateAvailableIcons:(void (^)(CGSize iconSize, NSUInteger iconScale, NSString* iconPath, BOOL* stop))enumerateBlock
{
	if(!enumerateBlock) return;

	if(_cachedInfoDictionary)
	{
		NSString* iconName = nil;
		NSDictionary* cfBundleIcons = _cachedInfoDictionary[@"CFBundleIcons"];
		if(!cfBundleIcons)
		{
			cfBundleIcons = _cachedInfoDictionary[@"CFBundleIcons~ipad"];
		}
		if(cfBundleIcons && [cfBundleIcons isKindOfClass:NSDictionary.class])
		{
			NSDictionary* cfBundlePrimaryIcon = cfBundleIcons[@"CFBundlePrimaryIcon"];
			
			if(cfBundlePrimaryIcon && [cfBundlePrimaryIcon isKindOfClass:NSDictionary.class])
			{
				NSString* potentialIconName = cfBundlePrimaryIcon[@"CFBundleIconName"];
				if(potentialIconName && [potentialIconName isKindOfClass:NSString.class])
				{
					iconName = potentialIconName;
				}
				else
				{
					NSArray* cfBundleIconFiles = cfBundlePrimaryIcon[@"CFBundleIconFiles"];
					if(cfBundleIconFiles && [cfBundleIconFiles isKindOfClass:NSArray.class])
					{
						NSString* oneIconFile = cfBundleIconFiles.firstObject;
						NSString* otherIconFile = cfBundleIconFiles.lastObject;
						iconName = [oneIconFile commonPrefixWithString:otherIconFile options:NSLiteralSearch];
					}
				}
			}
		}

		if(!iconName) return;

		void (^wrapperBlock)(NSString* iconPath, BOOL* stop) = ^(NSString* iconPath, BOOL* stop)
		{
			NSString* currentIconName = iconPath.lastPathComponent;
			NSString* iconSuffix = [currentIconName substringFromIndex:[iconName length]];
			NSArray* seperatedIconSuffix = [iconSuffix componentsSeparatedByString:@"@"];

			NSString* currentIconResolution = seperatedIconSuffix.firstObject;
			NSString* currentIconScale;
			if(seperatedIconSuffix.count > 1)
			{
				currentIconScale = seperatedIconSuffix.lastObject;
			}

			NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
			f.numberStyle = NSNumberFormatterDecimalStyle;

			NSArray* separatedIconSize = [currentIconResolution componentsSeparatedByString:@"x"];
			NSNumber* widthNum = [f numberFromString:separatedIconSize.firstObject];
			NSNumber* heightNum = [f numberFromString:separatedIconSize.lastObject];

			CGSize iconSize = CGSizeMake(widthNum.unsignedIntegerValue, heightNum.unsignedIntegerValue);

			NSUInteger scale = 1;
			if(currentIconScale)
			{
				NSNumber* scaleNum = [f numberFromString:currentIconScale];
				scale = scaleNum.unsignedIntegerValue;
			}

			enumerateBlock(iconSize, scale, iconPath, stop);
		};

		if(_isArchive)
		{
			NSString* iconPrefix = [NSString stringWithFormat:@"Payload/%@/%@", _cachedAppBundleName, iconName];
			[self enumerateArchive:^(struct archive_entry* entry, BOOL* stop)
			{
				NSString* currentSubpath = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
				if([currentSubpath hasPrefix:iconPrefix])
				{
					wrapperBlock(currentSubpath, stop);
				}
			}];
		}
		else
		{
			NSArray<NSString*>* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_path error:nil];
			for(NSString* fileName in files)
			{
				if([fileName hasPrefix:iconName])
				{
					NSString* iconPath = [_path stringByAppendingPathComponent:fileName];

					BOOL stop = NO;
					wrapperBlock(iconPath, &stop);
					if(stop) return;
				}
			}

		}
	}
}

- (UIImage*)iconForSize:(CGSize)size
{
	if(size.width != size.height)
	{
		//not supported
		return nil;
	}

	// Flow: Check if icon with the exact size exists
	// If not, take the next best one and scale it down

	//UIImage* imageToReturn;
	__block NSString* foundIconPath;

	// Attempt 1: Check for icon with exact size
	[self enumerateAvailableIcons:^(CGSize iconSize, NSUInteger iconScale, NSString* iconPath, BOOL* stop)
	{
		if(CGSizeEqualToSize(iconSize, size) && UIScreen.mainScreen.scale == iconScale)
		{
			foundIconPath = iconPath;
			//imageToReturn = imageWithSize([UIImage imageWithContentsOfFile:iconPath], size);
			*stop = YES;
		}
	}];

	if(!foundIconPath)
	{
		// Attempt 2: Check for icon with bigger size
		__block CGSize closestIconSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);

		[self enumerateAvailableIcons:^(CGSize iconSize, NSUInteger iconScale, NSString* iconPath, BOOL* stop)
		{
			if(iconSize.width > size.width && iconSize.width < closestIconSize.width)
			{
				closestIconSize = iconSize;
			}
		}];

		if(closestIconSize.width == CGFLOAT_MAX)
		{
			// Attempt 3: Take biggest icon and scale it up
			closestIconSize = CGSizeMake(0,0);
			[self enumerateAvailableIcons:^(CGSize iconSize, NSUInteger iconScale, NSString* iconPath, BOOL* stop)
			{
				if(iconSize.width > closestIconSize.width)
				{
					closestIconSize = iconSize;
				}
			}];
		}

		if(closestIconSize.width == 0) return nil;

		[self enumerateAvailableIcons:^(CGSize iconSize, NSUInteger iconScale, NSString* iconPath, BOOL* stop)
		{
			if(CGSizeEqualToSize(iconSize, closestIconSize))
			{
				closestIconSize = iconSize;
				foundIconPath = iconPath;
				*stop = YES;
			}
		}];
	}

	if(!foundIconPath) return nil;

	if(_isArchive)
	{
		__block NSData* iconData;

		struct archive_entry* iconEntry = [self archiveEntryForSubpath:foundIconPath];
		if(iconEntry)
		{
			size_t size = archive_entry_size(iconEntry);
			void* buf = malloc(size);
			size_t read = archive_read_data(_archive, buf, size);
			
			if(read == size)
			{
				iconData = [NSData dataWithBytes:buf length:size];
			}

			free(buf);
		}

		if(iconData)
		{
			return imageWithSize([UIImage imageWithData:iconData], size);
		}
	}
	else
	{
		return imageWithSize([UIImage imageWithContentsOfFile:foundIconPath], size);
	}
	return nil;
}

- (NSString*)displayName
{
	NSString* displayName = _cachedInfoDictionary[@"CFBundleDisplayName"];
	if(!displayName || ![displayName isKindOfClass:NSString.class])
	{
		displayName = _cachedInfoDictionary[@"CFBundleName"];
		if(!displayName || ![displayName isKindOfClass:NSString.class])
		{
			displayName = _cachedInfoDictionary[@"CFBundleExecutable"];
			if(!displayName || ![displayName isKindOfClass:NSString.class])
			{
				if(_isArchive)
				{
					displayName = [_cachedAppBundleName stringByDeletingPathExtension];
				}
				else
				{
					displayName = [[_path lastPathComponent] stringByDeletingPathExtension];
				}
			}
		}
	}
	return displayName;
}

- (NSString*)bundleIdentifier
{
	return _cachedInfoDictionary[@"CFBundleIdentifier"];
}

- (NSString*)versionString
{
	NSString* version = _cachedInfoDictionary[@"CFBundleShortVersionString"];
	if(!version)
	{
		version = _cachedInfoDictionary[@"CFBundleVersion"];
	}
	return version;
}

- (NSString*)sizeString
{
	return [NSByteCountFormatter stringFromByteCount:_cachedSize countStyle:NSByteCountFormatterCountStyleFile];
}

- (NSString*)bundlePath
{
	if(!_isArchive)
	{
		return _path;
	}
	return nil;
}

- (NSString*)registrationState
{
	return _cachedRegistrationState;
}

- (NSAttributedString*)detailedInfoTitle
{
	NSString* displayName = [self displayName];

	NSMutableDictionary* titleAttributes = @{
		NSFontAttributeName : [UIFont boldSystemFontOfSize:16]
	}.mutableCopy;
	NSMutableAttributedString* description = [NSMutableAttributedString new];

	if(_cachedPreviewIcon)
	{
		titleAttributes[NSBaselineOffsetAttributeName] = @9.0;

		NSTextAttachment* previewAttachment = [[NSTextAttachment alloc] init];
		previewAttachment.image = _cachedPreviewIcon;
		
		[description appendAttributedString:[NSAttributedString attributedStringWithAttachment:previewAttachment]];
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:titleAttributes]];
	}

	[description appendAttributedString:[[NSAttributedString alloc] initWithString:displayName attributes:titleAttributes]];
	
	return description.copy;
}

- (NSAttributedString*)detailedInfoDescription
{
	NSString* bundleId = [self bundleIdentifier];
	NSString* version = [self versionString];
	NSString* sizeString = [self sizeString];
	
	// Check if any bundles main binary runs unsandboxed
	__block BOOL isUnsandboxed = NO;
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop) {
		if([key isEqualToString:@"com.apple.private.security.container-required"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				isUnsandboxed = !valueNum.boolValue;
				if(isUnsandboxed) *stop = YES;
			}
		} else if([key isEqualToString:@"com.apple.private.security.no-container"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				isUnsandboxed = valueNum.boolValue;
				if(isUnsandboxed) *stop = YES;
			}
		} else if([key isEqualToString:@"com.apple.private.security.no-sandbox"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				isUnsandboxed = valueNum.boolValue;
				if(isUnsandboxed) *stop = YES;
			}
		}
	}];
	
	// Check if any bundles main binary can spawn an external binary
	__block BOOL isPlatformApplication = NO;
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop)
	{
		if([key isEqualToString:@"platform-application"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				isPlatformApplication = valueNum.boolValue;
				if(isPlatformApplication) *stop = YES;
			}
		}
	}];
	
	// Check if any bundles main binary can spawn an external binary as root
	__block BOOL hasPersonaMngmt = NO;
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop)
	{
		if([key isEqualToString:@"com.apple.private.persona-mgmt"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				hasPersonaMngmt = valueNum.boolValue;
				if(hasPersonaMngmt) *stop = YES;
			}
		}
	}];
	
	// Accessible containers
	// com.apple.developer.icloud-container-identifiers
	// com.apple.security.application-groups
	// Unrestricted if special entitlement
	
	__block BOOL unrestrictedContainerAccess = NO;
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop)
	{
		if([key isEqualToString:@"com.apple.private.security.storage.AppDataContainers"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if(valueNum && [valueNum isKindOfClass:NSNumber.class])
			{
				unrestrictedContainerAccess = valueNum.boolValue;
				if(hasPersonaMngmt) *stop = YES;
			}
		}
	}];
	
	__block NSMutableArray* accessibleContainers = [NSMutableArray new]; //array by design, should be ordered
	if(!unrestrictedContainerAccess)
	{
		[self enumerateAllInfoDictionaries:^(NSString *key, NSObject *value, BOOL *stop) {
			if([key isEqualToString:@"CFBundleIdentifier"])
			{
				NSString* valueStr = (NSString*)value;
				if([valueStr isKindOfClass:NSString.class])
				{
					[accessibleContainers addObject:valueStr];
				}
			}
		}];

		[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop)
		{
			if([key isEqualToString:@"com.apple.developer.icloud-container-identifiers"] || [key isEqualToString:@"com.apple.security.application-groups"] || [key isEqualToString:@"com.apple.security.system-groups"])
			{
				NSArray* valueArr = (NSArray*)value;
				if([valueArr isKindOfClass:NSArray.class])
				{
					for(NSString* containerID in valueArr)
					{
						if([containerID isKindOfClass:NSString.class])
						{
							if(![accessibleContainers containsObject:containerID])
							{
								[accessibleContainers addObject:containerID];
							}
						}
					}
				}
			}
		}];
	}

	// Accessible Keychain Groups
	// keychain-access-groups
	// Unrestricted if single * (maybe?)
	__block BOOL unrestrictedKeychainAccess = NO;
	__block NSMutableSet* accessibleKeychainGroups = [NSMutableSet new];
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop) {
		if([key isEqualToString:@"keychain-access-groups"])
		{
			NSArray* valueArr = (NSArray*)value;
			if([valueArr isKindOfClass:NSArray.class])
			{
				for(NSString* keychainID in valueArr)
				{
					if([keychainID isKindOfClass:NSString.class])
					{
						if([keychainID isEqualToString:@"*"])
						{
							unrestrictedKeychainAccess = YES;
						}
						else
						{
							[accessibleKeychainGroups addObject:keychainID];
						}
					}
				}
			}
		}
	}];

	__block NSMutableSet* URLSchemes = [NSMutableSet new];
	[self enumerateAllInfoDictionaries:^(NSString *key, NSObject *value, BOOL *stop) {
		if([key isEqualToString:@"CFBundleURLTypes"])
		{
			NSArray* valueArr = (NSArray*)value;
			if([valueArr isKindOfClass:NSArray.class])
			{
				for(NSDictionary* URLTypeDict in valueArr)
				{
					if([URLTypeDict isKindOfClass:NSDictionary.class])
					{
						NSArray* cURLSchemes = URLTypeDict[@"CFBundleURLSchemes"];
						if(cURLSchemes && [cURLSchemes isKindOfClass:NSArray.class])
						{
							for(NSString* URLScheme in cURLSchemes)
							{
								[URLSchemes addObject:URLScheme];
							}
						}
					}
				}
			}
		}
	}];
	
	__block NSMutableSet* allowedTccServices = [NSMutableSet new];
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop) {
		if([key isEqualToString:@"com.apple.private.tcc.allow"])
		{
			NSArray* valueArr = (NSArray*)value;
			if([valueArr isKindOfClass:NSArray.class])
			{
				for(NSString* serviceID in valueArr)
				{
					if([serviceID isKindOfClass:NSString.class])
					{
						NSString* displayName = commonTCCServices[serviceID];
						if(displayName == nil)
						{
							[allowedTccServices addObject:[serviceID stringByReplacingOccurrencesOfString:@"kTCCService" withString:@""]];
						}
						else
						{
							[allowedTccServices addObject:displayName];
						}
					}
				}
			}
		}
		else if ([key isEqualToString:@"com.apple.locationd.preauthorized"])
		{
			NSNumber* valueNum = (NSNumber*)value;
			if([valueNum isKindOfClass:NSNumber.class])
			{
				if([valueNum boolValue])
				{
					[allowedTccServices addObject:@"Location"];
				}
			}
		}
	}];

	__block NSMutableSet* allowedMGKeys = [NSMutableSet new];
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop) {
		if([key isEqualToString:@"com.apple.private.MobileGestalt.AllowedProtectedKeys"])
		{
			NSArray* valueArr = (NSArray*)value;
			if([valueArr isKindOfClass:NSArray.class])
			{
				for(NSString* protectedKey in valueArr)
				{
					if([protectedKey isKindOfClass:NSString.class])
					{
						[allowedMGKeys addObject:protectedKey];
					}
				}
			}
		}
	}];

	NSMutableParagraphStyle* leftAlignment = [[NSMutableParagraphStyle alloc] init];
	leftAlignment.alignment = NSTextAlignmentLeft;

	UIColor* dangerColor = [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection *traitCollection)
	{
		if(traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
		{
			return [UIColor orangeColor];
		}
		else
		{
			return [UIColor redColor];
		}
	}];

	UIColor* warningColor = [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection *traitCollection)
	{
		if(traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
		{
			return [UIColor yellowColor];
		}
		else
		{
			return [UIColor orangeColor];
		}
	}];

	NSMutableAttributedString* description = [NSMutableAttributedString new];
	
	NSDictionary* headerAttributes = @{
		NSFontAttributeName : [UIFont boldSystemFontOfSize:14],
		NSParagraphStyleAttributeName : leftAlignment
	};

	NSDictionary* bodyAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:11],
		NSParagraphStyleAttributeName : leftAlignment
	};

	NSDictionary* bodyWarningAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:11],
		NSParagraphStyleAttributeName : leftAlignment,
		NSForegroundColorAttributeName : warningColor
	};

	NSDictionary* bodyDangerAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:11],
		NSParagraphStyleAttributeName : leftAlignment,
		NSForegroundColorAttributeName : dangerColor
	};

	[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"Metadata" attributes:headerAttributes]];
	
	[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\nBundle Identifier: %@", bundleId] attributes:bodyAttributes]];
	[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\nVersion: %@", version] attributes:bodyAttributes]];
	[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\nSize: %@", sizeString] attributes:bodyAttributes]];
	
	[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nSandboxing" attributes:headerAttributes]];
	if(isUnsandboxed)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app runs unsandboxed and can access most of the file system." attributes:bodyWarningAttributes]];
	}
	else
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app runs sandboxed and can only access the containers listed below." attributes:bodyAttributes]];
	}

	[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nCapabilities" attributes:headerAttributes]];
	if(isPlatformApplication && isUnsandboxed && hasPersonaMngmt)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app can spawn its own embedded binaries with root privileges." attributes:bodyDangerAttributes]];
	}
	else if(isPlatformApplication && isUnsandboxed)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app can spawn arbitrary binaries as the mobile user." attributes:bodyWarningAttributes]];
	}
	else
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app can not spawn other binaries." attributes:bodyAttributes]];
	}

	if(allowedTccServices.count)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nPrivacy" attributes:headerAttributes]];
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app can access the following services without asking for permission:\n" attributes:bodyWarningAttributes]];
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSListFormatter localizedStringByJoiningStrings:[allowedTccServices allObjects]] attributes:bodyAttributes]];
	}
	
	if (allowedMGKeys.count)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nDevice Info" attributes:headerAttributes]];
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nThe app can access protected information about this device:\n" attributes:bodyWarningAttributes]];
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSListFormatter localizedStringByJoiningStrings:[allowedMGKeys allObjects]] attributes:bodyAttributes]];
	}
    
	if(unrestrictedContainerAccess || accessibleContainers.count)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nAccessible Containers" attributes:headerAttributes]];
		if(unrestrictedContainerAccess)
		{
			[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nUnrestricted, the app can access all data containers on the system." attributes:bodyDangerAttributes]];
		}
		else
		{
			for(NSString* containerID in accessibleContainers)
			{
				[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", containerID] attributes:bodyAttributes]];
			}
		}
	}

	if(unrestrictedKeychainAccess || accessibleKeychainGroups.count)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nAccessible Keychain Groups" attributes:headerAttributes]];
		if(unrestrictedKeychainAccess)
		{
			[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nUnrestricted, the app can access the entire keychain." attributes:bodyDangerAttributes]];
		}
		else
		{
			for(NSString* keychainID in accessibleKeychainGroups)
			{
				[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", keychainID] attributes:bodyAttributes]];
			}
		}
	}

	if(URLSchemes.count)
	{
		[description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\nURL Schemes" attributes:headerAttributes]];

		for(NSString* URLScheme in URLSchemes)
		{
			[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", URLScheme] attributes:bodyAttributes]];
		}
	}

	return description;
}

- (void)log
{
	NSLog(@"entitlements:");
	[self enumerateAllEntitlements:^(NSString *key, NSObject *value, BOOL *stop) {
		NSLog(@"%@ -> %@", key, value);
	}];
	
	NSLog(@"info dictionaries:");
	[self enumerateAllInfoDictionaries:^(NSString *key, NSObject *value, BOOL *stop) {
		NSLog(@"%@ -> %@", key, value);
	}];
}


@end
