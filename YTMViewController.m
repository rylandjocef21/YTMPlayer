#import "YTMViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface YTMViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) UIButton *playPauseButton;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *searchResults;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, assign) BOOL isPlaying;
@end

@implementation YTMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    self.searchResults = [NSMutableArray array];
    
    // 1. Classic Dark iOS Search Bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 20, self.view.frame.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search songs, artists, albums...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0]; // Spotify Green accent
    [self.view addSubview:self.searchBar];
    
    // 2. Results List (Spotify Style)
    CGFloat tableHeight = self.view.frame.size.height - 124;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, tableHeight) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.view addSubview:self.tableView];
    
    // 3. Persistent Mini Player at Bottom
    [self setupNowPlayingBar];
    
    // 4. Background Audio Config
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self setupRemoteCommandCenter];
}

- (void)setupNowPlayingBar {
    CGFloat barY = self.view.frame.size.height - 60;
    self.nowPlayingView = [[UIView alloc] initWithFrame:CGRectMake(0, barY, self.view.frame.size.width, 60)];
    self.nowPlayingView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    
    self.nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, self.view.frame.size.width - 80, 40)];
    self.nowPlayingLabel.textColor = [UIColor whiteColor];
    self.nowPlayingLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.nowPlayingLabel.text = @"Not Playing";
    [self.nowPlayingView addSubview:self.nowPlayingLabel];
    
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playPauseButton.frame = CGRectMake(self.view.frame.size.width - 50, 15, 30, 30);
    [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    [self.playPauseButton setTitleColor:[UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0] forState:UIControlStateNormal];
    [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.nowPlayingView addSubview:self.playPauseButton];
    
    [self.view addSubview:self.nowPlayingView];
}

#import "YTMViewController.h"

// ... (Previous imports and setup)

#pragma mark - Search & InnerTube Logic

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (query.length == 0) return;
    
    [self searchYouTubeMusic:query completion:^(NSArray *results) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.searchResults removeAllObjects];
            [self.searchResults addObjectsFromArray:results];
            [self.tableView reloadData];
        });
    }];
}

- (void)searchYouTubeMusic:(NSString *)query completion:(void(^)(NSArray *results))completion {
    NSURL *url = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/search"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *payload = @{
        @"context": @{
            @"client": @{
                @"clientName": @"WEB_REMIX",
                @"clientVersion": @"1.20231214.00.00"
            }
        },
        @"query": query
    };
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) { completion(@[]); return; }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *parsedTracks = [NSMutableArray array];
        
        // Parsing InnerTube Search Response
        NSArray *sections = json[@"contents"][@"tabbedSearchResultsRenderer"][@"tabs"][0][@"tabRenderer"][@"content"][@"sectionListRenderer"][@"contents"];
        for (NSDictionary *section in sections) {
            NSArray *items = section[@"musicShelfRenderer"][@"contents"];
            for (NSDictionary *item in items) {
                NSDictionary *data = item[@"musicTwoRowItemRenderer"];
                NSString *videoId = data[@"navigationEndpoint"][@"watchEndpoint"][@"videoId"];
                NSString *title = data[@"title"][@"runs"][0][@"text"];
                NSString *artist = data[@"subtitle"][@"runs"][0][@"text"];
                
                if (videoId && title) {
                    [parsedTracks addObject:@{
                        @"videoId": videoId,
                        @"title": title,
                        @"artist": artist ?: @"Unknown Artist"
                    }];
                }
            }
        }
        completion(parsedTracks);
    }];
    [task resume];
}

#pragma mark - TableView Delegate / DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"TrackCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    
    NSDictionary *track = self.searchResults[indexPath.row];
    cell.textLabel.text = track[@"title"];
    cell.detailTextLabel.text = track[@"artist"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *selectedTrack = self.searchResults[indexPath.row];
    
    self.nowPlayingLabel.text = [NSString stringWithFormat:@"%@ - %@", selectedTrack[@"title"], selectedTrack[@"artist"]];
    [self fetchAndStreamVideoId:selectedTrack[@"videoId"] title:selectedTrack[@"title"] artist:selectedTrack[@"artist"]];
}

#pragma mark - Playback Control

- (void)fetchAndStreamVideoId:(NSString *)videoId title:(NSString *)title artist:(NSString *)artist {
    NSURL *url = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/player"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *payload = @{
        @"context": @{@"client": @{@"clientName": @"WEB_REMIX", @"clientVersion": @"1.20231214.00.00"}},
        @"videoId": videoId
    };
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *formats = json[@"streamingData"][@"adaptiveFormats"];
        
        for (NSDictionary *format in formats) {
            if ([format[@"mimeType"] containsString:@"audio/mp4"]) {
                NSString *streamUrl = format[@"url"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.audioPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:streamUrl]];
                    [self.audioPlayer play];
                    self.isPlaying = YES;
                    [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
                    
                    // Lockscreen Metadata
                    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
                        MPMediaItemPropertyTitle: title,
                        MPMediaItemPropertyArtist: artist,
                        MPNowPlayingInfoPropertyPlaybackRate: @(1.0)
                    };
                });
                break;
            }
        }
    }];
    [task resume];
}

- (void)togglePlayPause {
    if (!self.audioPlayer) return;
    if (self.isPlaying) {
        [self.audioPlayer pause];
        [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    } else {
        [self.audioPlayer play];
        [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
    }
    self.isPlaying = !self.isPlaying;
}

- (void)setupRemoteCommandCenter {
    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];
    [cc.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.audioPlayer play];
        self.isPlaying = YES;
        [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [cc.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.audioPlayer pause];
        self.isPlaying = NO;
        [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

@end
