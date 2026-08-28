#import "YTMViewController.h"
#import "YTMNetworkClient.h"
#import "YTMTrackParser.h"
#import "YTMPlayerManager.h"

@interface TrackCell : UITableViewCell
@property (nonatomic, strong) UIImageView *art;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@implementation TrackCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if (!(self = [super initWithStyle:style reuseIdentifier:rid])) return nil;
    self.backgroundColor = [UIColor clearColor];
    self.art = [[UIImageView alloc] initWithFrame:CGRectMake(12,8,56,56)];
    self.art.layer.cornerRadius = 4;
    self.art.clipsToBounds = YES;
    [self.contentView addSubview:self.art];

    // Use boldSystemFont for compatibility with older iOS versions (iOS 9 target)
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(80,10, self.contentView.bounds.size.width - 100, 22)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor whiteColor];
    [self.contentView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(80,32, self.contentView.bounds.size.width - 100, 20)];
    self.subtitleLabel.font = [UIFont systemFontOfSize:13];
    self.subtitleLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.subtitleLabel];

    return self;
}
@end

@interface YTMViewController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *playerBar;
@property (nonatomic, strong) UIImageView *playerArt;
@property (nonatomic, strong) UILabel *playerTitle;
@property (nonatomic, strong) UILabel *playerArtist;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UISlider *progressSlider;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *results;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *history;
@property (nonatomic, strong) YTMTrackParser *parser;
@end

@implementation YTMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    self.parser = [YTMTrackParser new];
    self.results = [NSMutableArray array];
    [self loadHistory];

    CGFloat top = 44;
    self.segment = [[UISegmentedControl alloc] initWithItems:@[ @"Search", @"History" ]];
    self.segment.selectedSegmentIndex = 0;
    self.segment.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];
    self.segment.frame = CGRectMake(12, top, self.view.bounds.size.width - 24, 30);
    [self.segment addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segment];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, top + 44, self.view.bounds.size.width, 56)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search songs or artists";
    self.searchBar.barStyle = UIBarStyleBlack;
    // UISearchBarStyleMinimal is available on iOS 7+, keep it but avoid newer styles
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:self.searchBar];

    CGFloat tableY = CGRectGetMaxY(self.searchBar.frame);
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, self.view.bounds.size.width, self.view.bounds.size.height - tableY - 72) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[TrackCell class] forCellReuseIdentifier:@"TrackCell"];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];

    [self setupPlayerBar];
    // Initialize player manager
    [YTMPlayerManager sharedManager];
}

- (void)setupPlayerBar {
    CGFloat h = 72;
    CGFloat y = self.view.bounds.size.height - h;
    self.playerBar = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, h)];
    self.playerBar.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];
    self.playerBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;

    self.playerArt = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 56, 56)];
    self.playerArt.layer.cornerRadius = 4;
    self.playerArt.clipsToBounds = YES;
    [self.playerBar addSubview:self.playerArt];

    // Use boldSystemFont for compatibility
    self.playerTitle = [[UILabel alloc] initWithFrame:CGRectMake(80, 10, self.view.bounds.size.width - 170, 22)];
    self.playerTitle.font = [UIFont boldSystemFontOfSize:14];
    self.playerTitle.textColor = [UIColor whiteColor];
    [self.playerBar addSubview:self.playerTitle];

    self.playerArtist = [[UILabel alloc] initWithFrame:CGRectMake(80, 32, self.view.bounds.size.width - 170, 18)];
    self.playerArtist.font = [UIFont systemFontOfSize:12];
    self.playerArtist.textColor = [UIColor lightGrayColor];
    [self.playerBar addSubview:self.playerArtist];

    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playPauseButton.frame = CGRectMake(self.view.bounds.size.width - 56, 18, 44, 36);
    // Use simple glyphs which are supported on iOS 9; fallback to text if needed
    [self.playPauseButton setTitle:@"▶︎" forState:UIControlStateNormal];
    self.playPauseButton.titleLabel.font = [UIFont systemFontOfSize:28];
    [self.playPauseButton addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.playerBar addSubview:self.playPauseButton];

    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(80, 54, self.view.bounds.size.width - 160, 10)];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    [self.playerBar addSubview:self.progressSlider];

    [self.view addSubview:self.playerBar];
}

#pragma mark - Search
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *q = searchBar.text;
    if (q.length == 0) return;
    [searchBar resignFirstResponder];
    __weak typeof(self) weak = self;
    [[YTMNetworkClient sharedClient] searchYouTubeMusic:q completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !json) {
                // show a tiny alert (UIAlertController is iOS 8+ — our target is iOS 9 so it's fine)
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Search failed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [weak presentViewController:a animated:YES completion:nil];
                return;
            }
            NSArray *tracks = [weak.parser parseTracksFromResponse:json];
            [weak.results removeAllObjects];
            [weak.results addObjectsFromArray:tracks];
            [weak.tableView reloadData];
        });
    }];
}

#pragma mark - Table
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.segment.selectedSegmentIndex == 0) ? self.results.count : self.history.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TrackCell" forIndexPath:indexPath];
    NSDictionary *track = (self.segment.selectedSegmentIndex == 0) ? self.results[indexPath.row] : self.history[indexPath.row];
    cell.titleLabel.text = track[@"title"] ?: @"Unknown";
    cell.subtitleLabel.text = track[@"artist"] ?: @"";
    // art: if track contains artworkUrl, load it async; otherwise set placeholder color
    cell.art.backgroundColor = [UIColor darkGrayColor];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *track = (self.segment.selectedSegmentIndex == 0) ? self.results[indexPath.row] : self.history[indexPath.row];
    [self addToHistory:track];

    self.playerTitle.text = track[@"title"];
    self.playerArtist.text = track[@"artist"];

    __weak typeof(self) weak = self;
    [[YTMNetworkClient sharedClient] playerForVideoId:track[@"videoId"] completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !json) {
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Playback error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [weak presentViewController:a animated:YES completion:nil];
                return;
            }
            NSArray *formats = json[@"streamingData"][@"adaptiveFormats"] ?: json[@"streamingData"][@"formats"];
            NSString *playUrl = nil;
            for (NSDictionary *f in formats) {
                NSString *u = f[@"url"];
                if (u.length) { playUrl = u; break; }
            }
            if (playUrl) {
                [[YTMPlayerManager sharedManager] playURLString:playUrl title:track[@"title"] artist:track[@"artist"]];
                [weak.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
            } else {
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"No playable stream" message:@"This track requires a proxy to resolve the stream." preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [weak presentViewController:a animated:YES completion:nil];
            }
        });
    }];
}

#pragma mark - History
- (void)loadHistory {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"YTMPlayerHistory"];
    if (saved) self.history = [saved mutableCopy];
    else self.history = [NSMutableArray array];
}
- (void)addToHistory:(NSDictionary *)track {
    if (!track) return;
    for (NSInteger i=0;i<self.history.count;i++){
        if ([self.history[i][@"videoId"] isEqualToString:track[@"videoId"]]) {
            [self.history removeObjectAtIndex:i];
            break;
        }
    }
    [self.history insertObject:track atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:self.history forKey:@"YTMPlayerHistory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadData];
}

#pragma mark - Player controls
- (void)togglePlay {
    YTMPlayerManager *mgr = [YTMPlayerManager sharedManager];
    [mgr togglePlayPause];
    BOOL playing = mgr.isPlaying;
    [self.playPauseButton setTitle:(playing?@"⏸":@"▶︎") forState:UIControlStateNormal];
}

#pragma mark - Segment
- (void)segChanged:(UISegmentedControl*)s {
    self.searchBar.hidden = (s.selectedSegmentIndex != 0);
    [self.tableView reloadData];
}

@end
