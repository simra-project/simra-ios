//
//  Regions.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Regions.h"
#import "NSString+hashCode.h"
#import "SimRa-Swift.h"

#define GET_SCHEME @"https:"
#ifdef DEBUG
#define GET_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define GET_HOST @"vm2.mcc.tu-berlin.de:8082"
#endif
#define GET_VERSION 12

@interface Regions ()
@property (strong, nonatomic) NSMutableArray <Region *> *regions;
@property (nonatomic) NSInteger regionId;
@property (nonatomic) NSInteger regionsId;
@property (nonatomic) NSInteger lastSeenRegionsId;
@property (nonatomic) BOOL loaded;
@property (strong, nonatomic) NSMutableArray <Region *> *closestsRegions;

@end

@implementation Regions

- (void)refresh {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    urlString = [NSString stringWithFormat:@"%@//%@/%d/check-regions?clientHash=%@&lastSeenRegionsID=%ld",
                 GET_SCHEME, GET_HOST, GET_VERSION,
                 NSString.clientHash,
                 (long)self.lastSeenRegionsId];
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

    if (dataString.length > 0 && lines.count > 0 && lines[0].length > 1) {
        self.regionsId = [lines[0] substringFromIndex:1].integerValue;
        self.regions = [[NSMutableArray alloc] init];
        for (NSInteger i = 1; i < lines.count; i++) {
            NSString *line = lines[i];
            NSMutableArray <NSString *> *fields = [[line componentsSeparatedByString:@"="] mutableCopy];
            NSLog(@"fields %@", fields);
            if (fields.count >= 3) {
                if ([fields[0] hasPrefix:@"!"]) {
                    fields[0] = [fields[0] substringFromIndex:1];
                    fields[2] = [NSString stringWithFormat:@"!%@",
                                 fields[2]];
                }
                Region *region = [[Region alloc] init];
                region.position = i - 1;
                region.englishDescription = fields[0];
                region.germanDescription = fields[1];
                region.identifier = fields[2];
                if (fields.count >= 4) {
                    NSString *coords = fields[3];
                    NSArray <NSString *> *latlon = [coords componentsSeparatedByString:@","];
                    if (latlon.count == 2) {
                        region.lat = [NSNumber numberWithDouble:latlon[0].doubleValue];
                        region.lon = [NSNumber numberWithDouble:latlon[1].doubleValue];
                    }
                }
                [self.regions addObject:region];
            }
        }
        [self save];
    }
    self.loaded = true;
}

+ (NSArray<NSString*>*)regionPropertyKeys {
    return @[@"identifier", @"englishDescription", @"germanDescription", @"lat", @"lon"];
}

- (void)save {
    NSMutableArray *arrayRegions = [[NSMutableArray alloc] init];
    for (Region *region in self.regions) {
        NSMutableDictionary *dictRegion = [[NSMutableDictionary alloc] init];
        for (NSString* strKey in self.class.regionPropertyKeys) {
            dictRegion[strKey] = [region valueForKey:strKey];
        }
        [arrayRegions addObject:dictRegion];
    }

//    [[NSUserDefaults standardUserDefaults] setObject:arrayRegions forKey:@"regions"];
    [Utility saveWithKey:@"regions" value:arrayRegions];
    
   
//    [[NSUserDefaults standardUserDefaults] setInteger:self.regionsId forKey:@"regionsId"];
//    [[NSUserDefaults standardUserDefaults] setInteger:self.lastSeenRegionsId forKey:@"lastSeenRegionsId"];
    [Utility saveIntWithKey:@"regionId" value:self.regionId];
    [Utility saveIntWithKey:@"regionsId" value:self.regionsId];
    [Utility saveIntWithKey:@"lastSeenRegionsId" value:self.lastSeenRegionsId];
    if (self.regionId < 0 || self.regionId > self.regions.count || self.regionId == nil) {
        self.regionId = 0;
    }
//    if (self.regionId == 0 || self.regionId < 0){
//        //create region specific profile
//        [Utility getPreferenceFilePathWithRegionWithRegionId:self.regionId];
//    }
    
}

- (void)seen {
    self.lastSeenRegionsId = self.regionsId;
    [self save];
}

- (instancetype)init {
    self = [super init];
    NSArray *arrayRegions = [[NSUserDefaults standardUserDefaults] arrayForKey:@"regions"];

    if (arrayRegions) {
        self.regions = [[NSMutableArray alloc] init];
        NSInteger position = 0;
        for (NSDictionary *dictRegion in arrayRegions) {
            Region *region = [[Region alloc] init];
            region.position = position++;
            for (NSString* strKey in self.class.regionPropertyKeys) {
                 [region setValue: dictRegion[strKey] forKey:strKey];
            }
            [self.regions addObject:region];
        }
    }

    self.regionId = [[NSUserDefaults standardUserDefaults] integerForKey:@"regionId"];
    self.lastSeenRegionsId = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastSeenRegionsId"];
    self.regionsId = [[NSUserDefaults standardUserDefaults] integerForKey:@"regionsId"];

    if (!self.regions) {
        self.regions = [[NSMutableArray alloc] init];
        NSURL *constantsURL = [[NSBundle mainBundle] URLForResource:@"constants" withExtension:@"plist" subdirectory:nil localization:@"de"];
        NSDictionary *germanConstants = [NSDictionary dictionaryWithContentsOfURL:constantsURL];
        NSArray *germanRegions = germanConstants[@"regions"];

        constantsURL = [[NSBundle mainBundle] URLForResource:@"constants" withExtension:@"plist" subdirectory:nil localization:@"Base"];
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

- (void)selectPosition:(NSInteger)position {
    if (position < self.regions.count) {
        self.regionId = position;
        [self save];
    }
}

- (NSArray<NSString *> *)regionTexts {
    NSMutableArray <NSString *> *texts = [[NSMutableArray alloc] init];
    for (Region *region in self.regions) {
        if (![region.identifier hasPrefix:@"!"]) {
            [texts addObject:region.localizedDescription];
        }
    }
    return texts;
}

- (void)computeClosestsRegions:(CLLocation *)location {
    self.closestsRegions = [[NSMutableArray alloc] init];
    for (Region *region in self.regions) {
        if (![region.identifier hasPrefix:@"!"]) {
            BOOL inserted = false;
            CLLocationDistance regionDistance = [region distanceFrom:location];
            for (NSInteger i = 0; i < self.closestsRegions.count; i++) {
                CLLocationDistance sortedRegionDistance = [self.closestsRegions[i] distanceFrom:location];
                if (regionDistance < sortedRegionDistance) {
                    [self.closestsRegions insertObject:region atIndex:i];
                    inserted = TRUE;
                    break;
                }
            }
            if (!inserted) {
                [self.closestsRegions addObject:region];
            }
        }
    }
    for (NSInteger i = 0; i < self.closestsRegions.count; i++) {
        NSLog(@"Region #%03ld/%03ld: %@ %.0f",
              i,
              self.closestsRegions[i].position,
              self.closestsRegions[i].identifier,
              [self.closestsRegions[i] distanceFrom:location]);

    }
}

- (BOOL)selectedIsOneOfThe3ClosestsRegions {
    return (self.closestsRegions.count < 1 ||
            (self.closestsRegions.count > 0 && self.regionId == self.closestsRegions[0].position) ||
            (self.closestsRegions.count > 1 && self.regionId == self.closestsRegions[1].position) ||
            (self.closestsRegions.count > 2 && self.regionId == self.closestsRegions[2].position)
            );
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
