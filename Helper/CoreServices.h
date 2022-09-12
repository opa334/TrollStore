@interface LSBundleProxy
@property (nonatomic,readonly) NSString * bundleIdentifier;
@property (nonatomic) NSURL* dataContainerURL;
-(NSString*)localizedName;
@end

@interface LSApplicationProxy : LSBundleProxy
+ (instancetype)applicationProxyForIdentifier:(NSString*)identifier;
@property NSURL* bundleURL;
@property NSString* bundleType;
@property NSString* canonicalExecutablePath;
@property (nonatomic,readonly) NSDictionary* groupContainerURLs;
@property (nonatomic,readonly) NSArray* plugInKitPlugins;
@property (getter=isInstalled,nonatomic,readonly) BOOL installed; 
@property (getter=isPlaceholder,nonatomic,readonly) BOOL placeholder; 
@property (getter=isRestricted,nonatomic,readonly) BOOL restricted;
@property (nonatomic,readonly) NSSet * claimedURLSchemes;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)registerApplicationDictionary:(NSDictionary*)dict;
- (BOOL)unregisterApplication:(id)arg1;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)uninstallApplication:(NSString*)arg1 withOptions:(id)arg2;
- (BOOL)openApplicationWithBundleID:(NSString *)arg1 ;
- (void)enumerateApplicationsOfType:(NSUInteger)type block:(void (^)(LSApplicationProxy*))block;
@end

@interface LSEnumerator : NSEnumerator
@property (nonatomic,copy) NSPredicate * predicate;
+ (instancetype)enumeratorForApplicationProxiesWithOptions:(NSUInteger)options;
@end

@interface LSPlugInKitProxy : LSBundleProxy
@property (nonatomic,readonly) NSString* pluginIdentifier;
@property (nonatomic,readonly) NSDictionary * pluginKitDictionary;
+ (instancetype)pluginKitProxyForIdentifier:(NSString*)arg1;
@end

@interface MCMContainer : NSObject
+ (id)containerWithIdentifier:(id)arg1 createIfNecessary:(BOOL)arg2 existed:(BOOL*)arg3 error:(id*)arg4;
@property (nonatomic,readonly) NSURL * url;
@end

@interface MCMDataContainer : MCMContainer

@end

@interface MCMAppDataContainer : MCMDataContainer

@end

@interface MCMAppContainer : MCMContainer
@end

@interface MCMPluginKitPluginDataContainer : MCMDataContainer
@end