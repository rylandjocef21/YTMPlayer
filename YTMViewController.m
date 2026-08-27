#import "YTMViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface YTMViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISegmentedControl *sectionSegment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;

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
    
    // 4. Now Playing Mini Player Bar
    [self setupNowPlayingBar];
    
    // 5. Audio Session Setup
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self setupRemoteCommandCenter];
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
    }
    [self.tableView reloadData];
}

#pragma mark - Piped / NewPipe Extractor Search API

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
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Uses Piped (NewPipe-backed) API
    NSString *urlString = [NSString stringWithFormat:@"https://pipedapi.kavin.rocks/search?q=%@&filter=music_songs", encodedQuery];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                       timeoutInterval:15.0];
    [request setHTTPMethod:@"GET"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            NSLog(@"[Piped Search Error]: %@", error.localizedDescription);
            completion(@[]);
            return;
        }
        
        id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *parsedTracks = [NSMutableArray array];
        
        NSArray *items = nil;
        if ([jsonResponse isKindOfClass:[NSDictionary class]]) {
            items = jsonResponse[@"items"];
        } else if ([jsonResponse isKindOfClass:[NSArray class]]) {
            items = (NSArray *)jsonResponse;
        }
        
        for (NSDictionary *item in items) {
            NSString *urlPath = item[@"url"];
            NSString *videoId = item[@"id"];
            if (!videoId && urlPath) {
                videoId = [urlPath stringByReplacingOccurrencesOfString:@"/watch?v=" withString:@""];
            }
            
            NSString *title = item[@"title"];
            NSString *artist = item[@"uploaderName"] ?: item[@"uploader"];
            
            if (videoId && title) {
                [parsedTracks addObject:@{
                    @"videoId": videoId,
                    @"title": title,
                    @"artist": artist ?: @"YouTube Music"
                }];
            }
        }
        
        completion(parsedTracks);
    }];
    [task resume];
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
    self.nowPlayingLabel.text = [NSString stringWithFormat:@"%@ - %@", selectedTrack[@"title"], selectedTrack[@"artist"]];
    [self fetchAndStreamVideoId:selectedTrack[@"videoId"] title:selectedTrack[@"title"] artist:selectedTrack[@"artist"]];
}

#pragma mark - Player Engine (Piped Audio Extraction)

- (void)fetchAndStreamVideoId:(NSString *)videoId title:(NSString *)title artist:(NSString *)artist {
    NSString *urlString = [NSString stringWithFormat:@"https://pipedapi.kavin.rocks/streams/%@", videoId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                       timeoutInterval:15.0];
    [request setHTTPMethod:@"GET"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) return;
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *audioStreams = json[@"audioStreams"];
        
        NSString *streamUrl = nil;
        
        // Find best m4a / mp4 direct audio stream link
        for (NSDictionary *stream in audioStreams) {
            NSString *mimeType = stream[@"mimeType"];
            if ([mimeType containsString:@"audio/mp4"] || [mimeType containsString:@"audio/m4a"]) {
                streamUrl = stream[@"url"];
                break;
            }
        }
        
        // Fallback to first available stream if mp4 not explicitly matched
        if (!streamUrl && audioStreams.count > 0) {
            streamUrl = audioStreams[0][@"url"];
        }
        
        if (streamUrl) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.audioPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:streamUrl]];
                [self.audioPlayer play];
                self.isPlaying = YES;
                [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
                
                [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
                    MPMediaItemPropertyTitle: title,
                    MPMediaItemPropertyArtist: artist,
                    MPNowPlayingInfoPropertyPlaybackRate: @(1.0)
                };
            });
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
