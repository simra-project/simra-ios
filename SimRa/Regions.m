//
//  Regions.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Regions.h"
#import "NSString+hashCode.h"

#define GET_SCHEME @"https:"
#ifdef DEBUG
#define GET_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define GET_HOST @"vm2.mcc.tu-berlin.de:8082"
#endif
#define GET_VERSION 10

@interface Regions ()
@property (strong, nonatomic) NSMutableArray <Region *> *regions;
@property (nonatomic) NSInteger regionId;

@end

@implementation Regions

- (void)refresh {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    urlString = [NSString stringWithFormat:@"%@//%@/check/regions?clientHash=%@",
                 GET_SCHEME, GET_HOST,
                 NSString.clientHash];
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

    self.regions = [[NSMutableArray alloc] init];

    NSArray <NSString *> *lines = [dataString componentsSeparatedByString:@"\n"];
    NSLog(@"lines %@", lines);
    for (NSString *line in lines) {
        NSMutableArray <NSString *> *fields = [[line componentsSeparatedByString:@"="] mutableCopy];
        NSLog(@"fields %@", fields);
        if (fields.count == 3) {
            if ([fields[0] hasPrefix:@"!"]) {
                fields[0] = [fields[0] substringFromIndex:1];
                fields[2] = [NSString stringWithFormat:@"!%@",
                             fields[2]];
            }
            Region *region = [[Region alloc] init];
            region.englishDescription = fields[0];
            region.germanDescription = fields[1];
            region.identifier = fields[2];
            [self.regions addObject:region];
        }
    }
    [self save];
}

- (void)save {
    NSMutableArray *arrayRegions = [[NSMutableArray alloc] init];
    for (Region *region in self.regions) {
        NSMutableDictionary *dictRegion = [[NSMutableDictionary alloc] init];
        dictRegion[@"identifier"] = region.identifier;
        dictRegion[@"englishDescription"] = region.englishDescription;
        dictRegion[@"germanDescription"] = region.germanDescription;
        [arrayRegions addObject:dictRegion];
    }

    [[NSUserDefaults standardUserDefaults] setObject:arrayRegions forKey:@"regions"];

    if (self.regionId < 0 || self.regionId > self.regions.count) {
        self.regionId = 0;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:self.regionId forKey:@"regionId"];
}

- (instancetype)init {
    self = [super init];
    NSArray *arrayRegions = [[NSUserDefaults standardUserDefaults] arrayForKey:@"regions"];

    if (arrayRegions) {
        self.regions = [[NSMutableArray alloc] init];
        for (NSDictionary *dictRegion in arrayRegions) {
            Region *region = [[Region alloc] init];
            region.identifier = dictRegion[@"identifier"];
            region.englishDescription = dictRegion[@"englishDescription"];
            region.germanDescription = dictRegion[@"germanDescription"];
            [self.regions addObject:region];
        }
    }

    self.regionId = [[NSUserDefaults standardUserDefaults] integerForKey:@"regionId"];

    if (!self.regions) {
        self.regions = [[NSMutableArray alloc] init];
        NSURL *bundleURL = [NSBundle mainBundle].bundleURL;

        NSURL *baseURL = [bundleURL URLByAppendingPathComponent:@"de.lproj"];
        NSURL *constantsURL = [baseURL URLByAppendingPathComponent:@"constants.plist"];
        NSDictionary *germanConstants = [NSDictionary dictionaryWithContentsOfURL:constantsURL];
        NSArray *germanRegions = germanConstants[@"regions"];

        baseURL = [bundleURL URLByAppendingPathComponent:@"Base.lproj"];
        constantsURL = [baseURL URLByAppendingPathComponent:@"constants.plist"];
        NSDictionary *englishConstants = [NSDictionary dictionaryWithContentsOfURL:constantsURL];
        NSArray *englishRegions = englishConstants[@"regions"];

        NSArray *localesArray = englishConstants[@"locales"];
        for (NSInteger i = 0; i < localesArray.count; i++) {
            Region *region = [[Region alloc] init];
            region.identifier = localesArray[i];
            if (i == 2) {
                region.identifier = [NSString stringWithFormat:@"!%@",
                                     region.identifier];
            }
            region.englishDescription = englishRegions[i];
            region.germanDescription = germanRegions[i];
            [self.regions addObject:region];
        }
    }
    [self save];

    [self refresh];

    return self;
}

- (BOOL)regionSelected {
    if (self.regionId == 0) {
        return false;
    } else {
        Region *region = self.regions[self.regionId];
        if ([region.identifier hasPrefix:@"!"]) {
            return false;
        }
        return true;
    }
}

- (void)selectId:(NSInteger)Id {
    NSInteger skipped = 0;
    self.regionId = 0;
    for (NSInteger i = 0; i < self.regions.count; i++) {
        Region *region = self.regions[i];
        if ([region.identifier hasPrefix:@"!"]) {
            skipped++;
        }
        if (Id + skipped == i) {
            self.regionId = i;
            break;
        }
    }
    [self save];
}

- (NSArray<NSString *> *)regionTexts {
    NSMutableArray <NSString *> *texts = [[NSMutableArray alloc] init];
    for (Region *region in self.regions) {
        if (![region.identifier hasPrefix:@"!"]) {
            if ([[NSLocale currentLocale].languageCode isEqualToString:@"de"]) {
                [texts addObject:region.germanDescription];
            } else {
                [texts addObject:region.englishDescription];
            }
        }
    }
    return texts;
}

- (Region *)currentRegion {
    return self.regions[self.regionId];
}

- (NSInteger)filteredRegionId {
    NSInteger skipped = 0;
    for (NSInteger i = 0; i < self.regions.count; i++) {
        Region *region = self.regions[i];
        if ([region.identifier hasPrefix:@"!"]) {
            skipped++;
        }
        if (self.regionId - skipped == i) {
            return i;
        }
    }
    return 0;
}

@end
