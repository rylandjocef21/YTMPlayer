#import "YTMViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface YTMViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISegmentedControl *sectionSegment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Mini Player UI
@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) UIButton *playPauseButton;

// Data Management
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *searchResults;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *historyResults;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, assign) BOOL isPlaying;
@end

@implementation YTMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    self.searchResults = [NSMutableArray array];
    [self loadHistory];
    
    // 1. Navigation Segment (Search vs History)
    self.sectionSegment = [[UISegmentedControl alloc] initWithItems:@[@"Search", @"History"]];
    self.sectionSegment.frame = CGRectMake(20, 28, self.view.frame.size.width - 40, 30);
    self.sectionSegment.selectedSegmentIndex = 0;
    self.sectionSegment.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];
    [self.sectionSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.sectionSegment];
    
    // 2. Search Bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search songs or artists...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];
    [self.view addSubview:self.searchBar];
    
    // 3. Results/History Table
    CGFloat tableY = 108;
    CGFloat tableHeight = self.view.frame.size.height - tableY - 60;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, self.view.frame.size.width, tableHeight) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.view addSubview:self.tableView];
    
    // 4. Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.loadingIndicator.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    // 5. Now Playing Mini Player Bar
    [self setupNowPlayingBar];
    
    // 6. Audio Session Setup & Remote Commands
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self setupRemoteCommandCenter];
    
    // 7. Track Playback Finish Observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup & Navigation

- (void)setupNowPlayingBar {
    CGFloat barY = self.view.frame.size.height - 60;
    self.nowPlayingView = [[UIView alloc] initWithFrame:CGRectMake(0, barY, self.view.frame.size.width, 60)];
    self.nowPlayingView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    
    self.nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, self.view.frame.size.width - 80, 40)];
    self.nowPlayingLabel.textColor = [UIColor whiteColor];
    self.nowPlayingLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
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

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        self.searchBar.hidden = NO;
        self.tableView.frame = CGRectMake(0, 108, self.view.frame.size.width, self.view.frame.size.height - 168);
    } else {
        self.searchBar.hidden = YES;
        self.tableView.frame = CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height - 124);
        [self loadHistory];
    }
    [self.tableView reloadData];
}

#pragma mark - InnerTube Search API

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (query.length == 0) return;
    
    [self.loadingIndicator startAnimating];
    
    [self searchYouTubeMusic:query completion:^(NSArray *results) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            [self.searchResults removeAllObjects];
            [self.searchResults addObjectsFromArray:results];
            [self.tableView reloadData];
        });
    }];
}

- (void)searchYouTubeMusic:(NSString *)query completion:(void(^)(NSArray *results))completion {
    NSString *urlString = @"https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlvU8O4R_4W16Y_019YpX4O_v9w";
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
    
    NSDictionary *payload = @{
        @"context": @{
            @"client": @{
                @"clientName": @"IOS",
                @"clientVersion": @"19.29.1",
                @"deviceMake": @"Apple",
                @"deviceModel": @"iPhone14,3",
                @"userInterfaceTheme": @"USER_INTERFACE_THEME_DARK",
                @"osName": @"iPhone",
                @"osVersion": @"15.6.0.19E257",
                @"hl": @"en",
                @"gl": @"US"
            }
        },
        @"query": query
    };
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            completion(@[]);
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *parsedTracks = [NSMutableArray array];
        
        [self extractTracksFromDictionary:json resultsContainer:parsedTracks];
        
        completion(parsedTracks);
    }];
    [task resume];
}

- (void)extractTracksFromDictionary:(id)node resultsContainer:(NSMutableArray *)container {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)node;
        
        NSDictionary *renderer = dict[@"videoRenderer"] ?: dict[@"compactVideoRenderer"] ?: dict[@"musicResponsiveListItemRenderer"];
        
        if (renderer) {
            NSString *videoId = renderer[@"videoId"];
            
            NSString *title = nil;
            if (renderer[@"title"][@"runs"][0][@"text"]) {
                title = renderer[@"title"][@"runs"][0][@"text"];
            } else if (renderer[@"title"][@"simpleText"]) {
                title = renderer[@"title"][@"simpleText"];
            }
            
            NSString *artist = nil;
            if (renderer[@"ownerText"][@"runs"][0][@"text"]) {
                artist = renderer[@"ownerText"][@"runs"][0][@"text"];
            } else if (renderer[@"shortBylineText"][@"runs"][0][@"text"]) {
                artist = renderer[@"shortBylineText"][@"runs"][0][@"text"];
            } else if (renderer[@"longBylineText"][@"runs"][0][@"text"]) {
                artist = renderer[@"longBylineText"][@"runs"][0][@"text"];
            }
            
            if (videoId.length > 0 && title.length > 0) {
                BOOL exists = NO;
                for (NSDictionary *t in container) {
                    if ([t[@"videoId"] isEqualToString:videoId]) {
                        exists = YES;
                        break;
                    }
                }
                if (!exists) {
                    [container addObject:@{
                        @"videoId": videoId,
                        @"title": title,
                        @"artist": artist ?: @"YouTube Track"
                    }];
                }
            }
        }
        
        for (id key in dict) {
            [self extractTracksFromDictionary:dict[key] resultsContainer:container];
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)node) {
            [self extractTracksFromDictionary:child resultsContainer:container];
        }
    }
}

#pragma mark - Table View Data & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.sectionSegment.selectedSegmentIndex == 0) ? self.searchResults.count : self.historyResults.count;
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
    
    NSDictionary *track = (self.sectionSegment.selectedSegmentIndex == 0) ? self.searchResults[indexPath.row] : self.historyResults[indexPath.row];
    cell.textLabel.text = track[@"title"];
    cell.detailTextLabel.text = track[@"artist"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *selectedTrack = (self.sectionSegment.selectedSegmentIndex == 0) ? self.searchResults[indexPath.row] : self.historyResults[indexPath.row];
    
    [self addToHistory:selectedTrack];
    self.nowPlayingLabel.text = [NSString stringWithFormat:@"Loading: %@...", selectedTrack[@"title"]];
    [self fetchAndStreamVideoId:selectedTrack[@"videoId"] title:selectedTrack[@"title"] artist:selectedTrack[@"artist"]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return (self.sectionSegment.selectedSegmentIndex == 1);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && self.sectionSegment.selectedSegmentIndex == 1) {
        [self.historyResults removeObjectAtIndex:indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:self.historyResults forKey:@"YTMPlayerHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Player Engine & Fallback Logic

- (void)fetchAndStreamVideoId:(NSString *)videoId title:(NSString *)title artist:(NSString *)artist {
    // Attempt 1: TVHTML5_SIMPLY_EMBEDDED_PLAYER
    [self fetchStreamURLWithContext:@"TVHTML5_SIMPLY_EMBEDDED_PLAYER" version:@"2.0" videoId:videoId completion:^(NSString *streamUrl) {
        if (streamUrl.length > 0) {
            [self startAudioPlaybackWithURL:streamUrl title:title artist:artist];
        } else {
            // Attempt 2: Fallback to ANDROID_VR Context
            [self fetchStreamURLWithContext:@"ANDROID_VR" version:@"1.65.10" videoId:videoId completion:^(NSString *fallbackUrl) {
                if (fallbackUrl.length > 0) {
                    [self startAudioPlaybackWithURL:fallbackUrl title:title artist:artist];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.nowPlayingLabel.text = @"Error: Track unavailable";
                    });
                }
            }];
        }
    }];
}

- (void)fetchStreamURLWithContext:(NSString *)clientName version:(NSString *)version videoId:(NSString *)videoId completion:(void(^)(NSString *url))completion {
    NSString *urlString = @"https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlvU8O4R_4W16Y_019YpX4O_v9w";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *payload = @{
        @"context": @{
            @"client": @{
                @"clientName": clientName,
                @"clientVersion": version
            }
        },
        @"videoId": videoId
    };
    
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) { completion(nil); return; }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *formats = json[@"streamingData"][@"adaptiveFormats"] ?: json[@"streamingData"][@"formats"];
        
        for (NSDictionary *format in formats) {
            NSString *url = format[@"url"];
            if (url.length > 0) {
                completion(url);
                return;
            }
        }
        completion(nil);
    }] resume];
}

- (void)startAudioPlaybackWithURL:(NSString *)streamUrl title:(NSString *)title artist:(NSString *)artist {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.audioPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:streamUrl]];
        [self.audioPlayer play];
        self.isPlaying = YES;
        self.nowPlayingLabel.text = [NSString stringWithFormat:@"%@ - %@", title, artist];
        [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
        
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyPlaybackRate: @(1.0)
        };
    });
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

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPlaying = NO;
        [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    });
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

#pragma mark - History Persistence

- (void)loadHistory {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"YTMPlayerHistory"];
    if (saved) {
        self.historyResults = [saved mutableCopy];
    } else {
        self.historyResults = [NSMutableArray array];
    }
}

- (void)addToHistory:(NSDictionary *)track {
    for (NSInteger i = 0; i < self.historyResults.count; i++) {
        if ([self.historyResults[i][@"videoId"] isEqualToString:track[@"videoId"]]) {
            [self.historyResults removeObjectAtIndex:i];
            break;
        }
    }
    [self.historyResults insertObject:track atIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.historyResults forKey:@"YTMPlayerHistory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
