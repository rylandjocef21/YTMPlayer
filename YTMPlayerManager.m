#import "YTMPlayerManager.h"
#import <MediaPlayer/MediaPlayer.h>

@interface YTMPlayerManager ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@end

@implementation YTMPlayerManager

+ (instancetype)sharedManager {
    static YTMPlayerManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [YTMPlayerManager new];
        [s setupAudioSessionAndRemote];
    });
    return s;
}

- (void)setupAudioSessionAndRemote {
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];
    __weak typeof(self) wself = self;
    [cc.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [wself.player play];
        wself.isPlaying = YES;
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [cc.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [wself.player pause];
        wself.isPlaying = NO;
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)playURLString:(NSString *)urlString title:(NSString *)title artist:(NSString *)artist {
    if (!urlString) return;
    NSURL *u = [NSURL URLWithString:urlString];
    if (!u) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.player = [AVPlayer playerWithURL:u];
        [self.player play];
        self.isPlaying = YES;
        NSMutableDictionary *now = [NSMutableDictionary dictionary];
        if (title) now[MPMediaItemPropertyTitle] = title;
        if (artist) now[MPMediaItemPropertyArtist] = artist;
        now[MPNowPlayingInfoPropertyPlaybackRate] = @(1.0);
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = now;
    });
}

- (void)togglePlayPause {
    if (!self.player) return;
    if (self.isPlaying) {
        [self.player pause];
        self.isPlaying = NO;
    } else {
        [self.player play];
        self.isPlaying = YES;
    }
}

- (void)stop {
    [self.player pause];
    self.player = nil;
    self.isPlaying = NO;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
}

@end
