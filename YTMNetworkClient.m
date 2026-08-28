#import "YTMNetworkClient.h"
#import "YTMConfig.h"

@implementation YTMNetworkClient

+ (instancetype)sharedClient {
    static YTMNetworkClient *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [YTMNetworkClient new];
    });
    return s;
}

- (NSURL *)baseURLForEndpoint:(NSString *)endpoint {
    if (YTMProxyBaseURL && YTMProxyBaseURL.length > 0) {
        return [NSURL URLWithString:[YTMProxyBaseURL stringByAppendingPathComponent:endpoint]];
    }
    NSString *urlString = [NSString stringWithFormat:@"https://www.youtube.com/youtubei/v1/%@?key=%@", endpoint, YTMInnerTubeApiKey ?: @""];
    return [NSURL URLWithString:urlString];
}

- (void)postInnerTubeEndpoint:(NSString *)endpoint
                     payload:(NSDictionary *)payload
                   completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion
{
    NSURL *url = [self baseURLForEndpoint:endpoint];
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"YTMNetworkClient" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    // Keep a safe User-Agent but allow override via proxy
    [req setValue:@"com.google.ios.youtube/19.29.1 (iPhone; CPU iOS 15_0 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
    NSData *body = nil;
    if (payload) {
        body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
        [req setHTTPBody:body];
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable resp, NSError * _Nullable err) {
        if (err) {
            if (completion) completion(nil, err);
            return;
        }
        if (!data) {
            if (completion) completion(nil, [NSError errorWithDomain:@"YTMNetworkClient" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"No data"}]);
            return;
        }
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr) {
            if (completion) completion(nil, jsonErr);
            return;
        }
        if (completion) completion(json, nil);
    }];
    [t resume];
}

- (void)searchYouTubeMusic:(NSString *)query completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion {
    NSDictionary *payload = @{
        @"context": @{
                @"client": @{
                        @"clientName": @"IOS",
                        @"clientVersion": @"19.29.1",
                        @"hl": @"en",
                        @"gl": @"US"
                }
        },
        @"query": query
    };
    [self postInnerTubeEndpoint:@"search" payload:payload completion:completion];
}

- (void)playerForVideoId:(NSString *)videoId completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion {
    NSDictionary *payload = @{
        @"context": @{
                @"client": @{
                        @"clientName": @"TVHTML5_SIMPLY_EMBEDDED_PLAYER",
                        @"clientVersion": @"2.0"
                }
        },
        @"videoId": videoId
    };
    [self postInnerTubeEndpoint:@"player" payload:payload completion:completion];
}

@end
