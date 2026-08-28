#import "YTMTrackParser.h"

@interface YTMTrackParser ()
- (void)extractTracksFromNode:(id)node container:(NSMutableArray *)container;
@end

@implementation YTMTrackParser

- (NSArray<NSDictionary *> *)parseTracksFromResponse:(NSDictionary *)json {
    NSMutableArray *out = [NSMutableArray array];
    [self extractTracksFromNode:json container:out];
    return out;
}

- (void)extractTracksFromNode:(id)node container:(NSMutableArray *)container {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = node;
        NSDictionary *renderer = dict[@"videoRenderer"] ?: dict[@"compactVideoRenderer"] ?: dict[@"musicResponsiveListItemRenderer"];
        if (renderer) {
            NSString *videoId = renderer[@"videoId"];
            NSString *title = nil;
            if (renderer[@"title"][@"runs"] && [renderer[@"title"][@"runs"] count] > 0) {
                title = renderer[@"title"][@"runs"][0][@"text"];
            } else if (renderer[@"title"][@"simpleText"]) {
                title = renderer[@"title"][@"simpleText"];
            }
            NSString *artist = nil;
            if (renderer[@"ownerText"][@"runs"] && [renderer[@"ownerText"][@"runs"] count] > 0) {
                artist = renderer[@"ownerText"][@"runs"][0][@"text"];
            } else if (renderer[@"shortBylineText"][@"runs"] && [renderer[@"shortBylineText"][@"runs"] count] > 0) {
                artist = renderer[@"shortBylineText"][@"runs"][0][@"text"];
            } else if (renderer[@"longBylineText"][@"runs"] && [renderer[@"longBylineText"][@"runs"] count] > 0) {
                artist = renderer[@"longBylineText"][@"runs"][0][@"text"];
            }
            if (videoId.length > 0 && title.length > 0) {
                BOOL exists = NO;
                for (NSDictionary *t in container) {
                    if ([t[@"videoId"] isEqualToString:videoId]) { exists = YES; break; }
                }
                if (!exists) {
                    [container addObject:@{"videoId": videoId,
                                           @"title": title,
                                           @"artist": artist ?: @"YouTube Track"}];
                }
            }
        }
        for (id key in dict) {
            [self extractTracksFromNode:dict[key] container:container];
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)node) {
            [self extractTracksFromNode:child container:container];
        }
    }
}

@end
