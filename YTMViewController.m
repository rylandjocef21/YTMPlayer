#import "YTMViewController.h"
#import "YTMNetworkClient.h"
#import "YTMTrackParser.h"
#import "YTMPlayerManager.h"

@interface YTMViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISegmentedControl *sectionSegment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *searchResults;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *historyResults;
@property (nonatomic, strong) YTMTrackParser *parser;
@end

@implementation YTMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    self.searchResults = [NSMutableArray array];
    [self loadHistory];
    self.parser = [YTMTrackParser new];

    // UI
    self.sectionSegment = [[UISegmentedControl alloc] initWithItems:@[@"Search",@"History"]];
    self.sectionSegment.frame = CGRectMake(20,28,self.view.frame.size.width-40,30);
    self.sectionSegment.selectedSegmentIndex = 0;
    self.sectionSegment.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];
    [self.sectionSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.sectionSegment];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,64,self.view.frame.size.width,44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search songs or artists...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];
    [self.view addSubview:self.searchBar];

    CGFloat tableY = 108;
    CGFloat tableHeight = self.view.frame.size.height - tableY - 60;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0,tableY,self.view.frame.size.width,tableHeight) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.view addSubview:self.tableView];

    [self setupNowPlayingBar];
    // Audio session + remote controls handled in YTMPlayerManager
    [YTMPlayerManager sharedManager];
}

#pragma mark - UI Helpers
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
        self.tableView.frame = CGRectMake(0,108,self.view.frame.size.width,self.view.frame.size.height - 168);
    } else {
        self.searchBar.hidden = YES;
        self.tableView.frame = CGRectMake(0,64,self.view.frame.size.width,self.view.frame.size.height - 124);
    }
    [self.tableView reloadData];
}

#pragma mark - Search
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (query.length == 0) return;
    __weak typeof(self) wself = self;
    [[YTMNetworkClient sharedClient] searchYouTubeMusic:query completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error || !json) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // minimally show empty
                [wself.searchResults removeAllObjects];
                [wself.tableView reloadData];
            });
            return;
        }
        NSArray *tracks = [wself.parser parseTracksFromResponse:json];
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself.searchResults removeAllObjects];
            [wself.searchResults addObjectsFromArray:tracks];
            [wself.tableView reloadData];
        });
    }];
}

#pragma mark - Table
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

    __weak typeof(self) wself = self;
    [[YTMNetworkClient sharedClient] playerForVideoId:selectedTrack[@"videoId"] completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error || !json) {
            // TODO: better UI feedback
            return;
        }
        // Try to extract a playable URL (formats/adaptiveFormats)
        NSArray *formats = json[@"streamingData"][@"adaptiveFormats"] ?: json[@"streamingData"][@"formats"];
        NSString *playUrl = nil;
        for (NSDictionary *f in formats) {
            NSString *u = f[@"url"];
            if (u && u.length > 0) {
                playUrl = u; break;
            }
            // handle signatureCipher case: the client should not try to decipher; recommend proxy
            NSString *cipher = f[@"signatureCipher"] ?: f[@"cipher"];
            if (cipher && cipher.length > 0) {
                // prefer server/proxy to resolve signature; skip here
                continue;
            }
        }
        if (playUrl) {
            [[YTMPlayerManager sharedManager] playURLString:playUrl title:selectedTrack[@"title"] artist:selectedTrack[@"artist"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
            });
        } else {
            // no usable URL on client — recommend proxy / show error
        }
    }];
}

#pragma mark - Player controls
- (void)togglePlayPause {
    [[YTMPlayerManager sharedManager] togglePlayPause];
    BOOL playing = [YTMPlayerManager sharedManager].isPlaying;
    [self.playPauseButton setTitle:(playing ? @"⏸" : @"▶") forState:UIControlStateNormal];
}

#pragma mark - History
- (void)loadHistory {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"YTMPlayerHistory"];
    if (saved) self.historyResults = [saved mutableCopy];
    else self.historyResults = [NSMutableArray array];
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
