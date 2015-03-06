#import "LSHTTPClientHook.h"

@interface LSServerConnectionHook : LSHTTPClientHook

+ (NSString *)methodNameForType:(NSInteger)type;
+ (NSString *)urlStringWithEndpoint:(NSString *)endpoint;

@end
