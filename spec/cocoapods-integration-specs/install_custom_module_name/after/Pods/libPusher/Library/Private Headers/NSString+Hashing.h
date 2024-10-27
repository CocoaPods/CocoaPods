#import <Foundation/Foundation.h>

@interface NSString (Hashing)
- (NSString *)MD5Hash;
- (NSString *)HMACDigestUsingSecretKey:(id)secretKey;
@end
