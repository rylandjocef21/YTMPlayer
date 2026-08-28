#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YTMPlayerManager : NSObject

@property (nonatomic, readonly) BOOL isPlaying;

+ (instancetype)sharedManager;
- (void)playURLString:(NSString *)urlString title:(nullable NSString *)title artist:(nullable NSString *)artist;
- (void)togglePlayPause;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
