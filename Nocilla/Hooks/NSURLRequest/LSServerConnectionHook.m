#import "LSServerConnectionHook.h"
#import "LSNocilla.h"
#import "LSStubRequest.h"
#import <objc/runtime.h>

@implementation LSServerConnectionHook

- (void)load {
    [self swizzleSelector:@selector(callEndPoint:withName:withParameters:withCompletionBlock:withErrorBlock:) fromClass:NSClassFromString(@"ServerConnection") toClass:[self class]];
}

- (void)unload {
    [self swizzleSelector:@selector(callEndPoint:withName:withParameters:withCompletionBlock:withErrorBlock:) fromClass:NSClassFromString(@"ServerConnection") toClass:[self class]];
}

- (void)swizzleSelector:(SEL)selector fromClass:(Class)original toClass:(Class)stub {
    
    Method originalMethod = class_getClassMethod(original, selector);
    Method stubMethod = class_getClassMethod(stub, selector);
    if (!originalMethod || !stubMethod) {
        [NSException raise:NSInternalInconsistencyException format:@"******* TESTING ****** Couldn't load ServerConnection hook."];
    }
    method_exchangeImplementations(originalMethod, stubMethod);
}

+ (void)callEndPoint:(NSInteger)type withName:(NSString *)name withParameters:(NSDictionary *)parameters withCompletionBlock:(void (^)(id responseObject))completionBlock withErrorBlock:(void (^)(NSError *error, NSInteger statusCode, NSInteger errorCode, NSString *errorMessage))errorBlock {
    NSURL *url = [LSServerConnectionHook urlWithEndpoint:name];
    NSString *method = [LSServerConnectionHook methodNameForType:type];
    NSLog(@"******* TESTING ****** Mocking request for: (%@) %@", method, url.absoluteString);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];
    LSStubResponse *stubbedResponse = [[LSNocilla sharedInstance] responseForRequest:request];
    
    // Set any cookies
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookies:[NSHTTPCookie cookiesWithResponseHeaderFields:stubbedResponse.headers forURL:request.URL]
                       forURL:request.URL mainDocumentURL:request.URL];
    
    if ((stubbedResponse.shouldFail || stubbedResponse.statusCode >= 400) && errorBlock) {
        NSError *error = stubbedResponse.error;
        errorBlock(error, 0, error.code, error.localizedDescription);
    } else {
        if (completionBlock) {
            NSError *error;
            id response = [NSJSONSerialization JSONObjectWithData:stubbedResponse.body options:0 error:&error];
            if (error) {
                [NSException raise:NSInternalInconsistencyException format:@"******* TESTING ****** Error parsing the JSON body.\nError: %@", error];
            }
            completionBlock(response);
        }
    }
}
    
+ (NSString *)methodNameForType:(NSInteger)type {
    if (type == 0) return @"GET";
    if (type == 1) return @"PUT";
    if (type == 2) return @"POST";
    if (type == 3) return @"DELETE";
    NSAssert(NO, @"******* TESTING ****** Invalid REST method type provided for calling into the server connection.");
    return nil;
}

+ (NSURL *)urlWithEndpoint:(NSString *)endpoint {
    NSString *serverProtocol = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ServerProtocol"];
    NSString *serverAddress = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ServerAddress"];
    NSString *serverPort = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ServerPort"];
    NSString *urlString = [NSString stringWithFormat:@"%@%@:%@%@", serverProtocol, serverAddress, serverPort, [endpoint stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return [NSURL URLWithString:urlString];
}

@end
