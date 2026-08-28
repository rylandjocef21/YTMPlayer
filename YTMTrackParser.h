#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YTMTrackParser : NSObject

// Returns array of track dictionaries with keys: videoId, title, artist
- (NSArray<NSDictionary *> *)parseTracksFromResponse:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END
