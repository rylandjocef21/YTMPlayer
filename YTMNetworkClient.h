#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YTMNetworkClient : NSObject

+ (instancetype)sharedClient;

// Generic POST to youtubei/v1 endpoints (inner tube) or to proxy if configured
- (void)postInnerTubeEndpoint:(NSString *)endpoint
                     payload:(NSDictionary *)payload
                   completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion;

// Convenience helpers
- (void)searchYouTubeMusic:(NSString *)query completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion;
- (void)playerForVideoId:(NSString *)videoId completion:(void(^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
