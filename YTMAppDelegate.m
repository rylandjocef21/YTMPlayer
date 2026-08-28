#import "YTMAppDelegate.h"
#import "YTMViewController.h"
#import "YTMPlayerManager.h"

@implementation YTMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Initialize audio session and player early to catch any AVAudioSession errors
    @try {
        [YTMPlayerManager sharedManager];
    } @catch (NSException *ex) {
        NSLog(@"YTMPlayerManager init exception: %@ - %@", ex.name, ex.reason);
    }

    YTMViewController *root = [[YTMViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    nav.navigationBar.translucent = NO;
    nav.navigationBar.barTintColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    nav.navigationBar.tintColor = [UIColor colorWithRed:0.11 green:0.84 blue:0.38 alpha:1.0];

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
