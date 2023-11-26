#import <stdbool.h>
#import <Foundation/Foundation.h>

int codesign_sign_adhoc(const char *path, bool preserveMetadata, NSDictionary *customEntitlements);