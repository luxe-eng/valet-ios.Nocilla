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
        NSError *error = nil;
        
        Class serverConnection = NSClassFromString(@"ServerConnection");
        SEL callErrorBlockSelector = NSSelectorFromString(@"callErrorBlock:withError:withOperation:");
        
        // Create an operation w/ response & responseObject
        Class requestOperationClass = NSClassFromString(@"AFHTTPRequestOperation");
        SEL initWithRequestSelector = NSSelectorFromString(@"initWithRequest:");
        id operation = [[requestOperationClass alloc] performSelector:initWithRequestSelector withObject:request];
        
        Class responseClass = NSClassFromString(@"NSHTTPURLResponse");
        SEL initWithSelector = NSSelectorFromString(@"initWithURL:statusCode:HTTPVersion:headerFields:");
        id response = objc_msgSend([responseClass alloc], initWithSelector, url, stubbedResponse.statusCode, @"HTTP/1.1", stubbedResponse.headers);
        object_setIvar(operation, class_getInstanceVariable(requestOperationClass, [@"_response" UTF8String]), response);
        
        NSError *jsonError;
        id responseObject;
        if (stubbedResponse.body.length != 0) {
            responseObject = [NSJSONSerialization JSONObjectWithData:stubbedResponse.body options:0 error:&jsonError];
            if (jsonError) {
                [NSException raise:NSInternalInconsistencyException format:@"******* TESTING ****** Error parsing the JSON body.\nError: %@", error];
                return;
            }
        }
        if (responseObject) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [responseObject valueForKey:@"message"] };
            error = [NSError errorWithDomain:@"testing.luxeValet.com" code:[[responseObject valueForKey:@"code"] integerValue] userInfo:userInfo];
            object_setIvar(operation, class_getInstanceVariable(requestOperationClass, [@"_responseObject" UTF8String]), responseObject);
        }
        
        objc_msgSend(self, callErrorBlockSelector, errorBlock, error, operation);
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
