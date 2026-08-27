#import "YTMAppDelegate.h"
#import "YTMViewController.m"

@implementation YTMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[YTMViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
