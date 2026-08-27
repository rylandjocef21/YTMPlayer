#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface YTMViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@end

@implementation YTMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(20, 80, self.view.frame.size.width - 40, 40)];
    self.searchField.placeholder = @"Enter YouTube Video ID...";
    self.searchField.backgroundColor = [UIColor whiteColor];
    self.searchField.layer.cornerRadius = 5.0;
    [self.view addSubview:self.searchField];

    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.frame = CGRectMake(20, 140, self.view.frame.size.width - 40, 50);
    self.playButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:1.0];
    [self.playButton setTitle:@"Stream Track" forState:UIControlStateNormal];
    [self.playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(fetchAndPlayTrack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playButton];

    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    [self setupRemoteCommandCenter];
}

- (void)setupRemoteCommandCenter {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.audioPlayer play];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.audioPlayer pause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)fetchAndPlayTrack {
    NSString *videoId = self.searchField.text;
    if (videoId.length == 0) videoId = @"dQw4w9WgXcQ";

    [self getStreamUrlFromInnerTube:videoId completion:^(NSString *streamUrl, NSString *title) {
        if (!streamUrl) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = [NSURL URLWithString:streamUrl];
            self.audioPlayer = [AVPlayer playerWithURL:url];
            [self.audioPlayer play];

            NSDictionary *nowPlayingInfo = @{
                MPMediaItemPropertyTitle: title ?: @"InnerTube Track",
                MPNowPlayingInfoPropertyPlaybackRate: @(1.0)
            };
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
        });
    }];
}

- (void)getStreamUrlFromInnerTube:(NSString *)videoId completion:(void(^)(NSString *url, NSString *title))completion {
    NSURL *apiURL = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/player"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:apiURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"context": @{
            @"client": @{
                @"clientName": @"WEB_REMIX",
                @"clientVersion": @"1.20231214.00.00"
            }
        },
        @"videoId": videoId
    };

    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [request setHTTPBody:bodyData];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || !data) {
                completion(nil, nil);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *formats = json[@"streamingData"][@"adaptiveFormats"];
            NSString *title = json[@"videoDetails"][@"title"];
            NSString *audioUrl = nil;

            for (NSDictionary *format in formats) {
                NSString *mimeType = format[@"mimeType"];
                if ([mimeType containsString:@"audio/mp4"]) {
                    audioUrl = format[@"url"];
                    break;
                }
            }

            completion(audioUrl, title);
    }];
    [task resume];
}

@end
