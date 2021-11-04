//
//  News.m
//  SimRa
//
//  Created by Christoph Krey on 21.02.21.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "News.h"
#import "NSString+hashCode.h"
#import "SimRa-Swift.h"

#define GET_SCHEME @"https:"
#ifdef DEBUG
#define GET_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define GET_HOST @"vm2.mcc.tu-berlin.de:8082"
#endif


@interface News ()
@property (nonatomic) NSInteger newsVersion;
@property (nonatomic, strong) NSMutableArray <NSString *> *newsLines;

@end

@implementation News
- (void)refresh {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    urlString = [NSString stringWithFormat:@"%@//%@/check/news?clientHash=%@&lastSeenNewsID=%ld&newsLanguage=%@",
                 GET_SCHEME,
                 GET_HOST,
                 NSString.clientHash,
                 (long)self.newsVersion,
                 [NSBundle preferredLocalizationsFromArray:@[@"en", @"de"]].firstObject
                 ];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:urlString]];

    [request setValue:@"text/plain" forHTTPHeaderField: @"Content-Type"];
    [request setTimeoutInterval:10.0];
    NSLog(@"request:\n%@", request);

    NSURLSessionDataTask *dataTask =
    [
     [NSURLSession sharedSession]
     dataTaskWithRequest:request
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *connectionError) {

         if (connectionError) {
             NSLog(@"connectionError %@", connectionError);
         } else {
             NSLog(@"response %@ %@",
                   response,
                   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     [self performSelectorOnMainThread:@selector(process:)
                                            withObject:data
                                         waitUntilDone:NO];
                 } else {
                     //
                 }
             } else {
                 //
             }
         }
     }];

    [dataTask resume];
}

- (void)process:(NSData *)data {
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"dataString %@", dataString);
    NSArray <NSString *> *lines = [dataString componentsSeparatedByString:@"\n"];
    NSLog(@"lines %@", lines);
    NSInteger version = 0;
    if (lines.count > 0 && [lines[0] rangeOfString:@"#"].location == 0) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        version = [nf numberFromString:[lines[0] substringFromIndex:1]].integerValue;
    }
    if (version > 0) {
        for (NSInteger n = 1; n < lines.count; n++) {
            NSString *line = lines[n];
            NSLog(@"line %@", line);
            [self.newsLines addObject:line];
        }
        self.newsVersion = version;
    }
}

- (instancetype)init {
    self = [super init];
    self.newsLines = [[NSMutableArray alloc] init];
    self.newsVersion = [[NSUserDefaults standardUserDefaults] integerForKey:@"newsVersion"];

    [self refresh];
    return self;
}

- (void)seen {
//    [[NSUserDefaults standardUserDefaults] setInteger:self.newsVersion forKey:@"newsVersion"];
    [Utility saveIntWithKey:@"newsVersion" value:self.newsVersion];
}

@end
