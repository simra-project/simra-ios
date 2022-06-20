//
//  Trips.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Trips.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"
#import "SimRa-Swift.h"

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
    AppDelegate *ad = [AppDelegate sharedDelegate];
    
    self.version = [ad.defaults integerForKey:@"version"];
    self.uploaded = [ad.defaults boolForKey:@"uploaded"];
    self.fileHash = [ad.defaults stringForKey:@"fileHash"];
    self.filePasswd = [ad.defaults stringForKey:@"filePasswd"];

    self.tripInfos = [[NSMutableDictionary alloc] init];

    NSArray <NSNumber *> *allTripInfos = [[TripInfo allStoredIdentifiers] sortedArrayUsingSelector:@selector(compare:)];
    NSLog(@"allTripInfos %@", allTripInfos);

    for (NSNumber *anIdentifier in allTripInfos) {
        NSInteger identifier = anIdentifier.integerValue;
        NSLog(@"loading %ld", (long)identifier);
        TripInfo *tripInfo = [[TripInfo alloc] initFromStorage:identifier];
        [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:tripInfo.identifier]];
    }

    NSArray <NSNumber *> *allTrips = [[Trip allStoredIdentifiers] sortedArrayUsingSelector:@selector(compare:)];
    NSLog(@"allTrips %@", allTrips);

    for (NSNumber *anIdentifier in allTrips) {
        NSInteger identifier = anIdentifier.integerValue;

            TripInfo *tripInfo = [self.tripInfos objectForKey:[NSNumber numberWithInteger:identifier]];
            if (!tripInfo || tripInfo.annotationsCount == 0) {
                NSLog(@"loading %ld, (%ld)",
                      (long)identifier, (long)tripInfo.annotationsCount);
                Trip *trip = [[Trip alloc] initFromStorage:identifier];
                TripInfo *tripInfo = trip.tripInfo;
                [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:trip.identifier]];
                [trip save];
            } else {
                NSLog(@"already have info of %ld", (long)identifier);
            }
    }

    BOOL copyStatisticsOnce = [ad.defaults boolForKey:@"copyStatisticsOnce"];
    if (!copyStatisticsOnce) {
        [Utility saveBoolWithKey:@"copyStatisticsOnce" value:TRUE];
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
            
            [Utility saveIntWithKey:[@"totalRides" withRegionId:ad.regions.regionId] value:totalRides];
            [Utility saveIntWithKey:[@"totalDuration" withRegionId:ad.regions.regionId] value:totalDuration];
            [Utility saveIntWithKey:[@"totalIncidents" withRegionId:ad.regions.regionId] value:totalIncidents];
            [Utility saveIntWithKey:[@"totalLength" withRegionId:ad.regions.regionId] value:totalLength];
            [Utility saveIntWithKey:[@"totalIdle" withRegionId:ad.regions.regionId] value:totalIdle];
            [Utility saveIntWithKey:[@"numberOfScary" withRegionId:ad.regions.regionId] value:numberOfScary];
            [Utility saveArrayWithKey:[@"totalSlots" withRegionId:ad.regions.regionId] value:totalSlots];

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
    [self.tripInfos removeObjectForKey:[NSNumber numberWithInteger:identifier]];
    [Trip deleteFromStorage:identifier];
}

- (void)updateTrip:(Trip *)trip {
    TripInfo *tripInfo = trip.tripInfo;
    [self.tripInfos setObject:tripInfo forKey:[NSNumber numberWithInteger:trip.identifier]];
}

- (NSURL *)csvFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"/trips.csv"];
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
    
    AppDelegate *ad = [AppDelegate sharedDelegate];
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
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [Utility saveIntWithKey:[@"version" withRegionId:ad.regions.regionId] value:self.version];
    [Utility saveBoolWithKey:[@"uploaded" withRegionId:ad.regions.regionId] value:self.uploaded];
    [Utility saveStringWithKey:[@"fileHash" withRegionId:ad.regions.regionId] value:self.fileHash];
    [Utility saveStringWithKey:[@"filePasswd" withRegionId:ad.regions.regionId] value:self.filePasswd];
    [self saveUploadedTripToPlist];
}

-(void)saveUploadedTripToPlist{
    [Utility writeRegionBasedProfile];
}
- (void)addTripToStatistics:(Trip *)trip {
    AppDelegate *ad = [AppDelegate sharedDelegate];

    [self addTripToStatistics:trip regionId:0];
    if (ad.regions.regionSelected) {
        [self addTripToStatistics:trip regionId:ad.regions.regionId];
    }
}

- (void)addTripToStatistics:(Trip *)trip regionId:(NSInteger)regionId {
    AppDelegate *ad = [AppDelegate sharedDelegate];

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
    [Utility saveIntWithKey:[@"totalRides" withRegionId:regionId] value:totalRides];
    [Utility saveIntWithKey:[@"totalDuration" withRegionId:regionId] value:totalDuration];
    [Utility saveIntWithKey:[@"totalIncidents" withRegionId:regionId] value:totalIncidents];
    [Utility saveIntWithKey:[@"totalLength" withRegionId:regionId] value:totalLength];
    [Utility saveIntWithKey:[@"totalIdle" withRegionId:regionId] value:totalIdle];
    [Utility saveIntWithKey:[@"numberOfScary" withRegionId:regionId] value:numberOfScary];
    [Utility saveArrayWithKey:[@"totalSlots" withRegionId:regionId] value:totalSlots];

    [Utility writeProfile];

}

- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    AppDelegate *ad = [AppDelegate sharedDelegate];

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
