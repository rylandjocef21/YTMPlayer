#import "LTYouTubeClient.h"

NSString *const LTAPIKey = @"AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

@implementation LTYouTubeClient

+ (instancetype)sharedClient {
    static LTYouTubeClient *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[LTYouTubeClient alloc] init];
    });
    return shared;
}

// InnerTube POST request helper
- (void)postToHost:(NSString *)host path:(NSString *)path body:(NSDictionary *)body completion:(void (^)(id json, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://%@/youtubei/v1/%@?key=%@", host, path, LTAPIKey];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [request setHTTPBody:payload];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) completion(nil, error);
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (completion) completion(json, nil);
    }] resume];
}

// Fetch direct playback stream URL
- (void)streamURLForVideo:(NSString *)videoId completion:(void (^)(NSString *streamURL, BOOL muxedStream, NSError *error))completion {
    NSDictionary *body = @{
        @"context": @{
            @"client": @{
                @"clientName": @"ANDROID",
                @"clientVersion": @"21.26.364",
                @"gl": @"US",
                @"hl": @"en"
            }
        },
        @"videoId": videoId
    };

    [self postToHost:@"www.youtube.com" path:@"player" body:body completion:^(id json, NSError *error) {
        if (error) {
            if (completion) completion(nil, NO, error);
            return;
        }
        
        NSArray *adaptive = json[@"streamingData"][@"adaptiveFormats"];
        NSString *streamUrl = nil;
        for (NSDictionary *format in adaptive) {
            // Find standard audio ITAG (140 = 128k AAC)
            if ([format[@"itag"] intValue] == 140 && [format[@"url"] length]) {
                streamUrl = format[@"url"];
                break;
            }
        }
        
        if (completion) completion(streamUrl, NO, streamUrl ? nil : [NSError errorWithDomain:@"LTYouTube" code:404 userInfo:nil]);
    }];
}

@end
