//
//  Trips.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Trips.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"

//#warning DEBUG SIMULATE_NOT_RE_UPLOADED
//#define SIMULATE_NOT_RE_UPLOADED 2

@interface NSString (withRegionId)
- (NSString *)withRegionId:(NSInteger)regionId;
@end

@implementation NSString (withRegionId)
- (NSString *)withRegionId:(NSInteger)regionId {
    if (regionId == 0) {
        return self;
    } else {
        return [self stringByAppendingFormat:@"-%ld", regionId];
    }
}
@end

@implementation Trips
- (instancetype)init {
    self = [super init];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.version = [ad.defaults integerForKey:@"version"];
    self.uploaded = [ad.defaults boolForKey:@"uploaded"];
    self.fileHash = [ad.defaults stringForKey:@"fileHash"];
    self.filePasswd = [ad.defaults stringForKey:@"filePasswd"];

    self.tripInfos = [[NSMutableDictionary alloc] init];
    NSLog(@"defaults %@", ad.defaults.dictionaryRepresentation.allKeys);
    for (NSString *key in ad.defaults.dictionaryRepresentation.allKeys) {
        if ([key rangeOfString:@"TripInfo-"].location == 0) {
            NSLog(@"loading %@", key);
            NSDictionary *dict = [ad.defaults objectForKey:key];
            TripInfo *tripInfo = [[TripInfo alloc] initFromDictionary:dict];
#ifdef SIMULATE_NOT_RE_UPLOADED
            if (tripInfo.identifier <= SIMULATE_NOT_RE_UPLOADED) {
                tripInfo.reUploaded = FALSE;
            }
#endif
            [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:tripInfo.identifier]];
        }
    }

    for (NSString *key in ad.defaults.dictionaryRepresentation.allKeys) {
        if ([key rangeOfString:@"Trip-"].location == 0) {
            NSInteger identifier = [key substringFromIndex:5].integerValue;
            TripInfo *tripInfo = [self.tripInfos objectForKey:[NSNumber numberWithInteger:identifier]];
            if (!tripInfo || tripInfo.annotationsCount == 0) {
                NSLog(@"loading %@ (%ld)",
                      key, (long)tripInfo.annotationsCount);
                NSDictionary *dict = [ad.defaults objectForKey:key];
                Trip *trip = [[Trip alloc] initFromDictionary:dict];
                TripInfo *tripInfo = trip.tripInfo;
#ifdef SIMULATE_NOT_RE_UPLOADED
                if (tripInfo.identifier <= SIMULATE_NOT_RE_UPLOADED) {
                    tripInfo.reUploaded = FALSE;
                }
#endif
                [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:trip.identifier]];
                [trip save];
            } else {
                NSLog(@"already have info of %@", key);
            }
        }
    }

    BOOL copyStatisticsOnce = [ad.defaults boolForKey:@"copyStatisticsOnce"];
    if (!copyStatisticsOnce) {
        [ad.defaults setBool:TRUE forKey:@"copyStatisticsOnce"];

        if (ad.regions.regionSelected) {
            [self save];

            NSInteger totalRides = [ad.defaults integerForKey:@"totalRides"];
            NSInteger totalDuration = [ad.defaults integerForKey:@"totalDuration"];
            NSInteger totalIncidents = [ad.defaults integerForKey:@"totalIncidents"];
            NSInteger totalLength = [ad.defaults integerForKey:@"totalLength"];
            NSInteger totalIdle = [ad.defaults integerForKey:@"totalIdle"];
            NSInteger numberOfScary = [ad.defaults integerForKey:@"numberOfScary"];
            NSMutableArray <NSNumber *> *totalSlots = [[ad.defaults arrayForKey:@"totalSlots"] mutableCopy];
            if (!totalSlots) {
                totalSlots = [[NSMutableArray alloc] init];
                for (NSInteger i = 0; i < 24; i++) {
                    [totalSlots setObject:[NSNumber numberWithInteger:0] atIndexedSubscript:i];
                }
            }
            [ad.defaults setInteger:totalRides
                             forKey:[@"totalRides" withRegionId:ad.regions.regionId]];
            [ad.defaults setInteger:totalDuration
                             forKey:[@"totalDuration" withRegionId:ad.regions.regionId]];
            [ad.defaults setInteger:totalIncidents
                             forKey:[@"totalIncidents" withRegionId:ad.regions.regionId]];
            [ad.defaults setInteger:totalLength
                             forKey:[@"totalLength" withRegionId:ad.regions.regionId]];
            [ad.defaults setInteger:totalIdle
                             forKey:[@"totalIdle" withRegionId:ad.regions.regionId]];
            [ad.defaults setInteger:numberOfScary
                             forKey:[@"numberOfScary" withRegionId:ad.regions.regionId]];
            [ad.defaults setObject:totalSlots
                            forKey:[@"totalSlots" withRegionId:ad.regions.regionId]];
        }
    }

    return self;
}

- (Trip *)newTrip {
    Trip *trip = [[Trip alloc] init];
    TripInfo *tripInfo = trip.tripInfo;
    [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:trip.identifier]];
    return trip;
}

- (void)deleteTripWithIdentifier:(NSInteger)identifier {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"Trip-%ld", identifier]];
    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"TripInfo-%ld", identifier]];
    [self.tripInfos removeObjectForKey:[NSNumber numberWithInteger:identifier]];
}

- (void)updateTrip:(Trip *)trip {
    TripInfo *tripInfo = trip.tripInfo;
    [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:trip.identifier]];
}

- (NSURL *)csvFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trips.csv"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];
    
    NSString *csvString;
    
    NSString *bundleVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    NSArray <NSString *> *components = [bundleVersion componentsSeparatedByString:@"."];
    csvString = [NSString stringWithFormat:@"i%@#%ld\n",
                 components[0],
                 self.version];
    
    csvString = [csvString stringByAppendingString:@"birth,gender,region,experience,numberOfRides,duration,numberOfIncidents,length,idle,behaviour,numberOfScary"];
    for (NSInteger i = 0; i < 24; i++) {
        csvString = [csvString stringByAppendingFormat:@",%ld", i];
    }
    csvString = [csvString stringByAppendingString:@"\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    csvString = [NSString stringWithFormat:@"%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%@,%ld",
                 [ad.defaults integerForKey:@"ageId"],
                 [ad.defaults integerForKey:@"sexId"],
                 ad.regions.regionId,
                 [ad.defaults integerForKey:@"experienceId"],
                 [ad.defaults integerForKey:[@"totalRides" withRegionId:ad.regions.regionId]],
                 [ad.defaults integerForKey:[@"totalDuration" withRegionId:ad.regions.regionId]],
                 [ad.defaults integerForKey:[@"totalIncidents" withRegionId:ad.regions.regionId]],
                 [ad.defaults integerForKey:[@"totalLength" withRegionId:ad.regions.regionId]],
                 [ad.defaults integerForKey:[@"totalIdle" withRegionId:ad.regions.regionId]],
                 [ad.defaults boolForKey:@"behaviour"] ?
                    [NSString stringWithFormat:@"%ld",
                     [ad.defaults integerForKey:@"behaviourValue"]] :
                     @"",
                 [ad.defaults integerForKey:[@"numberOfScary" withRegionId:ad.regions.regionId]]];
    NSArray <NSNumber *> *totalSlots = [ad.defaults arrayForKey:[@"totalSlots" withRegionId:ad.regions.regionId]];
    for (NSInteger i = 0; i < 24; i++) {
        csvString = [csvString stringByAppendingFormat:@",%ld",
                     totalSlots[i].integerValue];
    }
    csvString = [csvString stringByAppendingString:@"\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
    return fileURL;
}

- (void)save {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:self.version
                     forKey:[@"version" withRegionId:ad.regions.regionId]];
    [ad.defaults setBool:self.uploaded
                  forKey:[@"uploaded" withRegionId:ad.regions.regionId]];
    [ad.defaults setObject:self.fileHash
                    forKey:[@"fileHash" withRegionId:ad.regions.regionId]];
    [ad.defaults setObject:self.filePasswd
                    forKey:[@"filePasswd" withRegionId:ad.regions.regionId]];
}

- (void)addTripToStatistics:(Trip *)trip {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    [self addTripToStatistics:trip regionId:0];
    if (ad.regions.regionSelected) {
        [self addTripToStatistics:trip regionId:ad.regions.regionId];
    }
}

- (void)addTripToStatistics:(Trip *)trip regionId:(NSInteger)regionId {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    NSInteger totalRides = [ad.defaults
                            integerForKey:[@"totalRides" withRegionId:regionId]];
    NSInteger totalDuration = [ad.defaults
                               integerForKey:[@"totalDuration" withRegionId:regionId]];
    NSInteger totalIncidents = [ad.defaults
                                integerForKey:[@"totalIncidents" withRegionId:regionId]];
    NSInteger totalLength = [ad.defaults
                             integerForKey:[@"totalLength" withRegionId:regionId]];
    NSInteger totalIdle = [ad.defaults
                           integerForKey:[@"totalIdle" withRegionId:regionId]];
    NSInteger numberOfScary = [ad.defaults
                               integerForKey:[@"numberOfScary" withRegionId:regionId]];
    NSMutableArray <NSNumber *> *totalSlots = [[ad.defaults
                                                arrayForKey:[@"totalSlots" withRegionId:regionId]] mutableCopy];
    if (!totalSlots) {
        totalSlots = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < 24; i++) {
            [totalSlots setObject:[NSNumber numberWithInteger:0] atIndexedSubscript:i];
        }
    }

    totalRides++;
    totalDuration += [trip.duration.endDate timeIntervalSinceDate:trip.duration.startDate] * 1000.0;
    totalIncidents += trip.tripValidAnnotations;
    totalLength += trip.length;
    totalIdle += trip.idle * 1000.0;
    numberOfScary += trip.numberOfScary;

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger hour;
    hour = [calendar component:NSCalendarUnitHour fromDate:trip.duration.startDate];
    [totalSlots setObject:[NSNumber numberWithInteger:totalSlots[hour].integerValue + 1] atIndexedSubscript:hour];
    hour = [calendar component:NSCalendarUnitHour fromDate:trip.duration.endDate];
    [totalSlots setObject:[NSNumber numberWithInteger:totalSlots[hour].integerValue + 1] atIndexedSubscript:hour];

    [ad.defaults setInteger:totalRides
                     forKey:[@"totalRides" withRegionId:regionId]];
    [ad.defaults setInteger:totalDuration
                     forKey:[@"totalDuration" withRegionId:regionId]];
    [ad.defaults setInteger:totalIncidents
                     forKey:[@"totalIncidents" withRegionId:regionId]];
    [ad.defaults setInteger:totalLength
                     forKey:[@"totalLength" withRegionId:regionId]];
    [ad.defaults setInteger:totalIdle
                     forKey:[@"totalIdle" withRegionId:regionId]];
    [ad.defaults setInteger:numberOfScary
                     forKey:[@"numberOfScary" withRegionId:regionId]];
    [ad.defaults setObject:totalSlots
                    forKey:[@"totalSlots" withRegionId:regionId]];
}

- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    self.version = [ad.defaults integerForKey:[@"version"
                                               withRegionId:ad.regions.regionId]];
    self.uploaded = [ad.defaults boolForKey:[@"uploaded"
                                             withRegionId:ad.regions.regionId]];
    self.fileHash = [ad.defaults stringForKey:[@"fileHash"
                                               withRegionId:ad.regions.regionId]];
    self.filePasswd = [ad.defaults stringForKey:[@"filePasswd"
                                                 withRegionId:ad.regions.regionId]];

    [super uploadFile:name WithController:controller error:error completion:completion];
}

@end
