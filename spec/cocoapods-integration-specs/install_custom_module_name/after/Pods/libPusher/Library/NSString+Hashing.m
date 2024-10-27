#import "NSString+Hashing.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSString (Hashing)

- (NSString *)MD5Hash;
{
  const char *cStr = [self UTF8String];
  unsigned char result[CC_MD5_DIGEST_LENGTH];
  
  CC_MD5( cStr, (CC_LONG)strlen(cStr), result );

  return [NSString stringWithFormat:
          @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
          result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
          result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]
          ];
}


- (NSString *)HMACDigestUsingSecretKey:(id)secretKey
{
  const char *cKey  = [secretKey cStringUsingEncoding:NSASCIIStringEncoding];
  const char *cData = [self cStringUsingEncoding:NSASCIIStringEncoding];
  
  unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
  
  CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
  
  NSMutableString *result = [[NSMutableString alloc] init];
  for (int i = 0; i < sizeof(cHMAC); i++) {
    [result appendFormat:@"%02x", cHMAC[i] & 0xff];
  }
  NSString *digest = [result copy];
  
  return digest;
}

@end
