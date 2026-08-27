#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LTYouTubeClient : NSObject

+ (instancetype)sharedClient;

// Network & API Requests
- (void)searchWithQuery:(NSString *)query 
                   type:(NSString *)type 
             completion:(void (^)(NSArray *items, NSError *error))completion;

- (void)streamURLForVideo:(NSString *)videoId 
               completion:(void (^)(NSString *streamURL, BOOL muxedStream, NSError *error))completion;

- (void)loadImageWithURL:(NSString *)urlString 
              completion:(void (^)(UIImage *image))completion;

@end
