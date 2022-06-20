//
//  Trip.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Trip.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"
#import "SimRa-Swift.h"
#import "API.h"

@implementation TripAnnotation
@end

@implementation TripMotion
@end

@implementation ClosePassInfo
@end

@implementation TripGyro
@end

@implementation TripLocation
- (instancetype)init {
    self = [super init];
    self.tripMotions = [[NSMutableArray alloc] init];
    return self;
}

- (CMAcceleration)minMaxOfMotions {
    if (self.tripMotions.count > 0) {
        CMAcceleration minOfMotions = {0.0, 0.0, 0.0};
        CMAcceleration maxOfMotions = {0.0, 0.0, 0.0};
        for (TripMotion *tripMotion in self.tripMotions) {
            minOfMotions.x = MIN(minOfMotions.x, tripMotion.x);
            minOfMotions.y = MIN(minOfMotions.y, tripMotion.y);
            minOfMotions.z = MIN(minOfMotions.z, tripMotion.z);
            maxOfMotions.x = MAX(maxOfMotions.x, tripMotion.x);
            maxOfMotions.y = MAX(maxOfMotions.y, tripMotion.y);
            maxOfMotions.z = MAX(maxOfMotions.z, tripMotion.z);
        }
        CMAcceleration resultAcceleration;
        resultAcceleration.x = maxOfMotions.x - minOfMotions.x;
        resultAcceleration.y = maxOfMotions.y - minOfMotions.y;
        resultAcceleration.z = maxOfMotions.z - minOfMotions.z;
        return resultAcceleration;
    } else {
        CMAcceleration defaultAcceleration = {0.0, 0.0, 0.0};
        return defaultAcceleration;
    }
}

@end

@implementation TripInfo
+ (NSArray <NSNumber *> *)allStoredIdentifiers {
    NSMutableArray <NSNumber *> *all = [[NSMutableArray alloc] init];

    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSArray <NSString *> *allKeys = [ad.defaults.dictionaryRepresentation.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSLog(@"TripInfo allStoredIdentifiers %@", allKeys);

    for (NSString *key in allKeys) {
        if ([key rangeOfString:@"TripInfo-"].location == 0) {
            NSInteger identifier = [key substringFromIndex:9].integerValue;
            NSNumber *anIdentifier = [NSNumber numberWithInteger:identifier];
            [all addObject:anIdentifier];
        }
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                      inDomains:NSUserDomainMask].firstObject;
    NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:documentDirectoryURL.path
                                                                     error:nil];
    NSLog(@"contents %@", contents);

    for (NSString *content in contents) {
        if ([content rangeOfString:@"TripInfo-"].location == 0) {
            NSInteger identifier = [content substringFromIndex:9].integerValue;
            BOOL found = FALSE;
            for (NSNumber *one in all) {
                if (one.integerValue == identifier) {
                    found = TRUE;
                }
            }
            if (!found) {
                NSNumber *anIdentifier = [NSNumber numberWithInteger:identifier];
                [all addObject:anIdentifier];
            }
        }
    }

    return all;
}

- (instancetype)initFromStorage:(NSInteger)identifier {
    NSLog(@"TripInfo initFromStorage %ld", identifier);

    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSDictionary *dict = [ad.defaults objectForKey:[NSString stringWithFormat:@"TripInfo-%ld",
                                                    identifier]];

    if (!dict) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
        NSURL *tripInfoURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"TripInfo-%ld.json", identifier]];

        NSData *jsonData = [fileManager contentsAtPath:tripInfoURL.path];
        dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                               options:0
                                                 error:nil];
    }
    return [self initFromDictionary:dict];
}


- (instancetype)initFromDictionary:(NSDictionary *)dict {
    self = [super init];
    NSNumber *identifier = [dict objectForKey:@"identifier"];
    self.identifier = identifier.integerValue;
    NSNumber *version = [dict objectForKey:@"version"];
    self.version = version.integerValue;
    NSNumber *edited = [dict objectForKey:@"edited"];
    self.edited = edited.boolValue;
    NSNumber *uploaded = [dict objectForKey:@"uploaded"];
    self.uploaded = uploaded.boolValue;
    NSNumber *statisticsAdded = [dict objectForKey:@"statisticsAdded"];
    self.statisticsAdded = statisticsAdded.boolValue;
    NSNumber *reUploaded = [dict objectForKey:@"reUploaded"];
    self.reUploaded = reUploaded.boolValue;
    NSNumber *annotationsCount = [dict objectForKey:@"annotationsCount"];
    self.annotationsCount = annotationsCount.integerValue;
    NSNumber *validAnnotationsCount = [dict objectForKey:@"validAnnotationsCount"];
    self.validAnnotationsCount = validAnnotationsCount.integerValue;

    self.fileHash = [dict objectForKey:@"fileHash"];
    self.filePasswd = [dict objectForKey:@"filePasswd"];

    NSNumber *start = [dict objectForKey:@"start"];
    NSNumber *end = [dict objectForKey:@"end"];
    self.duration = [[NSDateInterval alloc]
                     initWithStartDate:[NSDate dateWithTimeIntervalSince1970:start.doubleValue]
                     endDate:[NSDate dateWithTimeIntervalSince1970:end.doubleValue]
    ];
    NSNumber *length = [dict objectForKey:@"length"];
    self.length = length.integerValue;
    return self;
}

- (NSDictionary *)asDictionary {
    NSMutableDictionary *tripInfoDict = [[NSMutableDictionary alloc] init];
    [tripInfoDict setObject:[NSNumber numberWithInteger:self.identifier] forKey:@"identifier"];
    [tripInfoDict setObject:[NSNumber numberWithInteger:self.version] forKey:@"version"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.edited] forKey:@"edited"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.uploaded] forKey:@"uploaded"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.statisticsAdded] forKey:@"statisticsAdded"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.reUploaded] forKey:@"reUploaded"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.annotationsCount] forKey:@"annotationsCount"];
    [tripInfoDict setObject:[NSNumber numberWithBool:self.validAnnotationsCount] forKey:@"validAnnotationsCount"];

    if (self.fileHash) {
        [tripInfoDict setObject:self.fileHash forKey:@"fileHash"];
    }
    if (self.filePasswd) {
        [tripInfoDict setObject:self.filePasswd forKey:@"filePasswd"];
    }

    [tripInfoDict setObject:[NSNumber
                             numberWithDouble:self.duration.startDate.timeIntervalSince1970]
                     forKey:@"start"];
    [tripInfoDict setObject:[NSNumber
                             numberWithDouble:self.duration.endDate.timeIntervalSince1970]
                     forKey:@"end"];
    [tripInfoDict setObject:[NSNumber numberWithInteger:self.length] forKey:@"length"];
    return tripInfoDict;
}

- (NSData *)asJSONData {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.asDictionary
                                                       options:0
                                                         error:nil];
    return jsonData;
}

@end

@interface Trip ()
@property (nonatomic) NSInteger identifier;
@property (strong, nonatomic) CLLocation *startLocation;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) TripMotion *lastTripMotion;
@property (nonatomic) NSInteger deferredSecs;
@property (nonatomic) NSInteger deferredMeters;

@property (strong, nonatomic) NSTimer *timer;
@end

@implementation Trip

- (instancetype)init {
    self = [super init];

    AppDelegate *ad = [AppDelegate sharedDelegate];
    //    self.closePassArr = [[NSMutableArray alloc]init];

    NSInteger identifier = [ad.defaults integerForKey:@"lastTripId"];
    identifier ++;
    self.identifier = identifier;
    //    [ad.defaults setInteger:identifier forKey:@"lastTripId"];
    [Utility saveIntWithKey:@"lastTripId" value:identifier];

    self.edited = FALSE;
    self.uploaded = FALSE;
    self.statisticsAdded = FALSE;
    self.reUploaded = FALSE;
    self.tripLocations = [[NSMutableArray alloc] init];
    self.AIVersion = 0;
    return self;
}

+ (NSArray<NSNumber *> *)allStoredIdentifiers {
    NSMutableArray <NSNumber *> *all = [[NSMutableArray alloc] init];

    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSArray <NSString *> *allKeys = [ad.defaults.dictionaryRepresentation.allKeys sortedArrayUsingSelector:@selector(compare:)];

    for (NSString *key in allKeys) {
        if ([key rangeOfString:@"Trip-"].location == 0) {
            NSInteger identifier = [key substringFromIndex:5].integerValue;
            //NSNumber *anIdentifier = [NSNumber numberWithInteger:identifier];
            //[all addObject:anIdentifier];
            NSLog(@"[Trip] move from NSUserDefaults to Files %ld", identifier);
            Trip *trip = [[Trip alloc] initFromStorage:identifier];
            [trip save];
        }
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                      inDomains:NSUserDomainMask].firstObject;
    NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:documentDirectoryURL.path
                                                                     error:nil];
    NSLog(@"contents %@", contents);

    for (NSString *content in contents) {
        if ([content rangeOfString:@"Trip-"].location == 0) {
            NSInteger identifier = [content substringFromIndex:5].integerValue;
            BOOL found = FALSE;
            for (NSNumber *one in all) {
                if (one.integerValue == identifier) {
                    found = TRUE;
                }
            }
            if (!found) {
                NSNumber *anIdentifier = [NSNumber numberWithInteger:identifier];
                [all addObject:anIdentifier];
            }
        }
    }

    return all;
}

- (instancetype)initFromStorage:(NSInteger)identifier {
    NSLog(@"Trip initFromStorage %ld", identifier);
    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSDictionary *dict = [ad.defaults objectForKey:[NSString stringWithFormat:@"Trip-%ld",
                                                    identifier]];

    if (!dict) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
        NSURL *tripURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Trip-%ld.json", identifier]];

        NSData *jsonData = [fileManager contentsAtPath:tripURL.path];
        dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                               options:0
                                                 error:nil];
    }
    return [self initFromDictionary:dict];
}

+ (void)deleteFromStorage:(NSInteger)identifier {
    // Delete in UserDefaults
    //    AppDelegate *ad = [AppDelegate sharedDelegate];
    [Utility removeWithKey:[NSString stringWithFormat:@"Trip-%ld", identifier]];
    [Utility removeWithKey:[NSString stringWithFormat:@"TripInfo-%ld", identifier]];

    //    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"Trip-%ld", identifier]];
    //    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"TripInfo-%ld", identifier]];

    // Delete in Filesystem
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                      inDomains:NSUserDomainMask].firstObject;
    NSURL *tripURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Trip-%ld.json", identifier]];
    NSURL *tripInfoURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"TripInfo-%ld.json", identifier]];

    BOOL tripSuccess = [fileManager removeItemAtPath:tripURL.path
                                               error:nil];
    BOOL tripInfoSuccess = [fileManager removeItemAtPath:tripInfoURL.path
                                                   error:nil];

    NSLog(@"[Trip] deleteFromStorage tripSuccess=%d tripInfoSuccess=%d",
          tripSuccess, tripInfoSuccess);
}

- (instancetype)initFromDictionary:(NSDictionary *)dict {
    self = [super init];
    NSNumber *identifier = [dict objectForKey:@"identifier"];
    self.identifier = identifier.integerValue;
    NSNumber *version = [dict objectForKey:@"version"];
    self.version = version.integerValue;
    NSNumber *edited = [dict objectForKey:@"edited"];
    self.edited = edited.boolValue;
    NSNumber *uploaded = [dict objectForKey:@"uploaded"];
    self.uploaded = uploaded.boolValue;
    self.fileHash = [dict objectForKey:@"fileHash"];
    self.filePasswd = [dict objectForKey:@"filePasswd"];

    NSNumber *bikeTypeId = [dict objectForKey:@"bikeTypeId"];
    self.bikeTypeId = bikeTypeId.integerValue;
    NSNumber *positionId = [dict objectForKey:@"positionId"];
    self.positionId = positionId.integerValue;
    NSNumber *AIVersion = [dict objectForKey:@"AIVersion"];
    self.AIVersion = AIVersion.integerValue;
    NSNumber *deferredSecs = [dict objectForKey:@"deferredSecs"];
    self.deferredSecs = deferredSecs.integerValue;
    NSNumber *deferredMeters = [dict objectForKey:@"deferredMeters"];
    self.deferredMeters = deferredMeters.integerValue;

    NSNumber *childseat = [dict objectForKey:@"childseat"];
    self.childseat = childseat.boolValue;
    NSNumber *trailer = [dict objectForKey:@"trailer"];
    self.trailer = trailer.boolValue;
    NSNumber *statisticsAdded = [dict objectForKey:@"statisticsAdded"];
    self.statisticsAdded = statisticsAdded.boolValue;
    NSNumber *reUploaded = [dict objectForKey:@"reUploaded"];
    self.reUploaded = reUploaded.boolValue;

    self.tripLocations = [[NSMutableArray alloc] init];
    //    self.closePassArr = [[NSMutableArray alloc] init];
    //    NSMutableArray *closePass = [dict objectForKey:@"closePassValues"];
    //    for (NSDictionary *closePassInfoDict in closePass){
    //        NSNumber *leftSensor = [closePassInfoDict objectForKey:@"leftSensorVal"];
    //        NSNumber *rightSensor = [closePassInfoDict objectForKey:@"rightSensorVal"];
    //        NSNumber *lat = [closePassInfoDict objectForKey:@"lat"];
    //        NSNumber *lng = [closePassInfoDict objectForKey:@"lng"];
    //        NSDictionary *annotationDict  = [closePassInfoDict objectForKey:@"tripAnnotation"];
    //        NSNumber *incidentId = [annotationDict objectForKey:@"incidentId"];
    //        NSString *comment = [annotationDict objectForKey:@"comment"];
    //        TripAnnotation *annotation = [[TripAnnotation alloc]init];
    //        annotation.incidentId = [incidentId intValue];
    //        annotation.comment = comment;
    //        ClosePassInfo *closePass = [[ClosePassInfo alloc]init];
    //        closePass.leftSensorValue = leftSensor;
    //        closePass.rightSensorValue = rightSensor;
    //        closePass.location = [[CLLocation alloc]initWithLatitude:[lat doubleValue] longitude:[lng doubleValue]];
    ////        closePass.tripAnnotation = annotation;
    //
    //        [self.closePassArr addObject:closePass];
    //
    //    }

    NSArray *tripLocations = [dict objectForKey:@"tripLocations"];
    for (NSDictionary *tripLocationDict in tripLocations) {
        NSNumber *timestamp = [tripLocationDict objectForKey:@"timestamp"];
        NSNumber *lat = [tripLocationDict objectForKey:@"lat"];
        NSNumber *lon = [tripLocationDict objectForKey:@"lon"];
        NSNumber *speed = [tripLocationDict objectForKey:@"speed"];
        NSNumber *horizontalAccuracy = [tripLocationDict objectForKey:@"horizontalAccuracy"];

        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat.doubleValue,
                                                                       lon.doubleValue);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:coordinate
                                altitude:-1
                                horizontalAccuracy:horizontalAccuracy.doubleValue
                                verticalAccuracy:-1
                                course:-1
                                speed:speed.doubleValue
                                timestamp:[NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue]];

        NSNumber *a = [tripLocationDict objectForKey:@"a"];
        NSNumber *b = [tripLocationDict objectForKey:@"b"];
        NSNumber *c = [tripLocationDict objectForKey:@"c"];

        TripGyro *gyro = [[TripGyro alloc] init];
        gyro.x = a.doubleValue;
        gyro.y = b.doubleValue;
        gyro.z = c.doubleValue;

        TripLocation *tripLocation = [[TripLocation alloc] init];
        tripLocation.location = location;
        tripLocation.gyro = gyro;
        NSNumber *leftSensorValue = [tripLocationDict objectForKey:@"leftSensorVal"];
        NSNumber *rightSensorValue = [tripLocationDict objectForKey:@"rightSensorVal"];
        if (leftSensorValue != nil && rightSensorValue != nil){
            ClosePassInfo *closePass = [[ClosePassInfo alloc]init];
            closePass.leftSensorValue = leftSensorValue;
            closePass.rightSensorValue = rightSensorValue;
            tripLocation.closePassInfo = closePass;
        }
        tripLocation.tripMotions = [[NSMutableArray alloc] init];
        NSDictionary *tripMotionsArray = [tripLocationDict objectForKey:@"tripMotions"];
        for (NSDictionary *tripMotionDict in tripMotionsArray) {
            TripMotion *tripMotion = [[TripMotion alloc] init];
            NSNumber *x = [tripMotionDict objectForKey:@"x"];
            NSNumber *y = [tripMotionDict objectForKey:@"y"];
            NSNumber *z = [tripMotionDict objectForKey:@"z"];
            NSNumber *xl = [tripMotionDict objectForKey:@"xl"];
            NSNumber *yl = [tripMotionDict objectForKey:@"yl"];
            NSNumber *zl = [tripMotionDict objectForKey:@"zl"];
            NSNumber *xr = [tripMotionDict objectForKey:@"xr"];
            NSNumber *yr = [tripMotionDict objectForKey:@"yr"];
            NSNumber *zr = [tripMotionDict objectForKey:@"zr"];
            NSNumber *cr = [tripMotionDict objectForKey:@"cr"];
            NSNumber *timestamp = [tripMotionDict objectForKey:@"timestamp"];
            tripMotion.x = x.doubleValue;
            tripMotion.y = y.doubleValue;
            tripMotion.z = z.doubleValue;
            tripMotion.xl = xl.doubleValue;
            tripMotion.yl = yl.doubleValue;
            tripMotion.zl = zl.doubleValue;
            tripMotion.xr = xr.doubleValue;
            tripMotion.yr = yr.doubleValue;
            tripMotion.zr = zr.doubleValue;
            tripMotion.cr = cr.doubleValue;
            tripMotion.timestamp = timestamp.doubleValue;
            [tripLocation.tripMotions addObject:tripMotion];
        }

        tripLocation.tripAnnotation = nil;
        NSDictionary *tripAnnotationDict = [tripLocationDict objectForKey:@"tripAnnotation"];
        if (tripAnnotationDict) {
            TripAnnotation *tripAnnotation = [[TripAnnotation alloc] init];
            NSNumber *incidentId = [tripAnnotationDict objectForKey:@"incidentId"];
            tripAnnotation.incidentId = incidentId.integerValue;
            NSNumber *frightening = [tripAnnotationDict objectForKey:@"frightening"];
            tripAnnotation.frightening = frightening.boolValue;
            NSNumber *car = [tripAnnotationDict objectForKey:@"car"];
            tripAnnotation.car = car.boolValue;
            NSNumber *bus = [tripAnnotationDict objectForKey:@"bus"];
            tripAnnotation.bus = bus.boolValue;
            NSNumber *taxi = [tripAnnotationDict objectForKey:@"taxi"];
            tripAnnotation.taxi = taxi.boolValue;
            NSNumber *commercial = [tripAnnotationDict objectForKey:@"commercial"];
            tripAnnotation.commercial = commercial.boolValue;
            NSNumber *delivery = [tripAnnotationDict objectForKey:@"delivery"];
            tripAnnotation.delivery = delivery.boolValue;
            NSNumber *bicycle = [tripAnnotationDict objectForKey:@"bicycle"];
            tripAnnotation.bicycle = bicycle.boolValue;
            NSNumber *motorcycle = [tripAnnotationDict objectForKey:@"motorcycle"];
            tripAnnotation.motorcycle = motorcycle.boolValue;
            NSNumber *pedestrian = [tripAnnotationDict objectForKey:@"pedestrian"];
            tripAnnotation.pedestrian = pedestrian.boolValue;
            NSNumber *other = [tripAnnotationDict objectForKey:@"other"];
            tripAnnotation.other = other.boolValue;
            NSNumber *escooter = [tripAnnotationDict objectForKey:@"escooter"];
            tripAnnotation.escooter = escooter.boolValue;
            NSString *comment = [tripAnnotationDict objectForKey:@"comment"];
            tripAnnotation.comment = comment;

            tripLocation.tripAnnotation = tripAnnotation;
        }
        [self.tripLocations addObject:tripLocation];
    }

    // if no valid annotations, insert dummy
    if (!self.tripAnnotations) {
        TripLocation *location = self.tripLocations.firstObject;
        TripAnnotation *annotation = [[TripAnnotation alloc] init];
        annotation.incidentId = -5;
        location.tripAnnotation = annotation;
    }

    return self;
}

- (NSDictionary *)asDictionary {
    NSMutableDictionary *tripDict = [[NSMutableDictionary alloc] init];
    [tripDict setObject:[NSNumber numberWithInteger:self.identifier] forKey:@"identifier"];
    [tripDict setObject:[NSNumber numberWithInteger:self.version] forKey:@"version"];
    [tripDict setObject:[NSNumber numberWithBool:self.edited] forKey:@"edited"];
    [tripDict setObject:[NSNumber numberWithBool:self.uploaded] forKey:@"uploaded"];
    if (self.fileHash) {
        [tripDict setObject:self.fileHash forKey:@"fileHash"];
    }
    if (self.filePasswd) {
        [tripDict setObject:self.filePasswd forKey:@"filePasswd"];
    }

    [tripDict setObject:[NSNumber numberWithInteger:self.deferredSecs] forKey:@"deferredSecs"];
    [tripDict setObject:[NSNumber numberWithInteger:self.deferredMeters] forKey:@"deferredMeters"];
    [tripDict setObject:[NSNumber numberWithInteger:self.bikeTypeId] forKey:@"bikeTypeId"];
    [tripDict setObject:[NSNumber numberWithInteger:self.positionId] forKey:@"positionId"];
    [tripDict setObject:[NSNumber numberWithInteger:self.AIVersion] forKey:@"AIVersion"];

    [tripDict setObject:[NSNumber numberWithBool:self.childseat] forKey:@"childseat"];
    [tripDict setObject:[NSNumber numberWithBool:self.trailer] forKey:@"trailer"];
    [tripDict setObject:[NSNumber numberWithBool:self.statisticsAdded] forKey:@"statisticsAdded"];
    [tripDict setObject:[NSNumber numberWithBool:self.reUploaded] forKey:@"reUploaded"];
    //    if (!self.closePassArr){
    //        self.closePassArr = [[NSMutableArray alloc]init];
    //    }
    //    NSMutableArray *tripClosePassArray = [[NSMutableArray alloc] init];

    //    for (ClosePassInfo *closePassInfo in self.closePassArr){
    //        NSNumber *leftSensor =  closePassInfo.leftSensorValue;
    //        NSNumber *rightSensor = closePassInfo.rightSensorValue;
    //        CLLocation *lastLocationForClosePass = closePassInfo.location;
    //        TripAnnotation *tripAnnotation = closePassInfo.tripAnnotation;
    //
    //        NSMutableDictionary * dict = [[NSMutableDictionary alloc]init];
    //        [dict setObject:leftSensor forKey:@"leftSensorVal"];
    //        [dict setObject:rightSensor forKey:@"rightSensorVal"];
    //        [dict setObject:[NSNumber numberWithDouble:lastLocationForClosePass.coordinate.latitude] forKey:@"lat"];
    //        [dict setObject:[NSNumber numberWithDouble:lastLocationForClosePass.coordinate.longitude] forKey:@"lng"];
    //        NSMutableDictionary *tripAnnotationDict = [[NSMutableDictionary alloc] init];
    //        [tripAnnotationDict
    //         setObject:[NSNumber numberWithInteger:tripAnnotation.incidentId]
    //         forKey:@"incidentId"];
    //            [tripAnnotationDict
    //             setObject:tripAnnotation.comment
    //             forKey:@"comment"];
    //        [dict setObject:tripAnnotationDict forKey:@"tripAnnotation"];
    //        [tripClosePassArray addObject:dict];
    //    }
    //    [tripDict setObject:tripClosePassArray forKey:@"closePassValues"];

    NSMutableArray *tripLocationsArray = [[NSMutableArray alloc] init];
    for (TripLocation *tripLocation in self.tripLocations) {
        NSMutableDictionary *tripLocationDict = [self convertTripLocationToDictionary:tripLocation];
        [tripLocationsArray addObject:tripLocationDict];
    }
    [tripDict setObject:tripLocationsArray forKey:@"tripLocations"];
    return tripDict;
}
-(NSMutableDictionary *)convertTripLocationToDictionary:(TripLocation *)tripLocation{
    NSMutableDictionary *tripLocationDict = [[NSMutableDictionary alloc] init];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.location.timestamp.timeIntervalSince1970]
     forKey:@"timestamp"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.location.coordinate.latitude]
     forKey:@"lat"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.location.coordinate.longitude]
     forKey:@"lon"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.location.speed]
     forKey:@"speed"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.location.horizontalAccuracy]
     forKey:@"horizontalAccuracy"];
    if (tripLocation.closePassInfo != nil && tripLocation.closePassInfo.leftSensorValue != nil && tripLocation.closePassInfo.rightSensorValue != nil){
        NSNumber *leftSensor =  tripLocation.closePassInfo.leftSensorValue;
        NSNumber *rightSensor = tripLocation.closePassInfo.rightSensorValue;

        [tripLocationDict
         setObject:leftSensor
         forKey:@"leftSensorVal"];
        [tripLocationDict
         setObject:rightSensor
         forKey:@"rightSensorVal"];
    }
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.gyro.x]
     forKey:@"a"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.gyro.y]
     forKey:@"b"];
    [tripLocationDict
     setObject:[NSNumber numberWithDouble:tripLocation.gyro.z]
     forKey:@"c"];

    NSMutableArray *tripMotionsArray = [[NSMutableArray alloc] init];
    for (TripMotion *tripMotion in tripLocation.tripMotions) {
        NSMutableDictionary *tripMotionDict = [[NSMutableDictionary alloc] init];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.x]
         forKey:@"x"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.y]
         forKey:@"y"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.z]
         forKey:@"z"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.xl]
         forKey:@"xl"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.yl]
         forKey:@"yl"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.zl]
         forKey:@"zl"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.xr]
         forKey:@"xr"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.yr]
         forKey:@"yr"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.zr]
         forKey:@"zr"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.cr]
         forKey:@"cr"];
        [tripMotionDict
         setObject:[NSNumber numberWithDouble: tripMotion.timestamp]
         forKey:@"timestamp"];
        [tripMotionsArray addObject:tripMotionDict];
    }
    [tripLocationDict setObject:tripMotionsArray forKey:@"tripMotions"];


    if (tripLocation.tripAnnotation) {
        NSMutableDictionary *tripAnnotationDict = [[NSMutableDictionary alloc] init];
        [tripAnnotationDict
         setObject:[NSNumber numberWithInteger:tripLocation.tripAnnotation.incidentId]
         forKey:@"incidentId"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.frightening]
         forKey:@"frightening"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.car]
         forKey:@"car"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.commercial]
         forKey:@"commercial"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.delivery]
         forKey:@"delivery"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.bus]
         forKey:@"bus"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.taxi]
         forKey:@"taxi"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.pedestrian]
         forKey:@"pedestrian"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.bicycle]
         forKey:@"bicycle"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.motorcycle]
         forKey:@"motorcycle"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.other]
         forKey:@"other"];
        [tripAnnotationDict
         setObject:[NSNumber numberWithBool:tripLocation.tripAnnotation.escooter]
         forKey:@"escooter"];

        if (tripLocation.tripAnnotation.comment) {
            [tripAnnotationDict
             setObject:tripLocation.tripAnnotation.comment
             forKey:@"comment"];
        }

        [tripLocationDict setObject:tripAnnotationDict forKey:@"tripAnnotation"];
    }
    return tripLocationDict;
}
-(void)storeClosePassValueForTripWithLeftSensorVal: (NSNumber *)leftSensorVal rightSensorVal: (NSNumber *)rightSensorVal {
    //create a closePassInfo object
    //create a trip annotation object
    //store it in the last location captured
    //these are then saved and retrieved after the recording of the trip is finished.
    ClosePassInfo *closePassInfo = [[ClosePassInfo alloc]init];
    BOOL isValidLeftSensor = [self checkIncidentMinimumDistance:leftSensorVal];
    BOOL isValidRightSensor = [self checkIncidentMinimumDistance:rightSensorVal];
    if (isValidLeftSensor){
        closePassInfo.leftSensorValue = leftSensorVal;

    }
    if (isValidRightSensor){
        closePassInfo.rightSensorValue = rightSensorVal;

    }
    if (isValidLeftSensor || isValidRightSensor){
        self.tripLocations.lastObject.closePassInfo = closePassInfo;
        NSLog(@"close pass left sensor value: %@",self.tripLocations.lastObject.closePassInfo.leftSensorValue);
        NSLog(@"close pass right sensor value: %@",self.tripLocations.lastObject.closePassInfo.rightSensorValue);
        NSLog(@"Close pass value stored");
    }

}

-(void)storeClosePassValuesForTripCSVWithLeftSensor1Val: (NSNumber *)leftSensor1Val leftSensor2Val: (NSNumber *)leftSensor2Val rightSensor1Val: (NSNumber *)rightSensor1Val rightSensor2Val: (NSNumber *)rightSensor2Val{

    if ([self checkIncidentMinimumDistance:leftSensor1Val]) {
        self.tripLocations.lastObject.closePassInfo.leftSensor1Value = leftSensor1Val;

    }
    if ([self checkIncidentMinimumDistance:leftSensor2Val]){
        self.tripLocations.lastObject.closePassInfo.leftSensor2Value = leftSensor2Val;
    }
    if ([self checkIncidentMinimumDistance:rightSensor1Val]){
        self.tripLocations.lastObject.closePassInfo.rightSensor1Value = rightSensor1Val;

    }
    if ([self checkIncidentMinimumDistance:rightSensor2Val]){
        self.tripLocations.lastObject.closePassInfo.rightSensor2Value = rightSensor2Val;
    }
}

- (BOOL)checkIncidentMinimumDistance:(NSNumber *)sensorValue {
    return sensorValue.intValue < 150;
}

- (NSData *)asJSONData {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.asDictionary
                                                       options:0
                                                         error:nil];
    return jsonData;
}

- (NSURL *)csvFile {
    return [self csvFileWithHeader:TRUE];
}

- (NSURL *)csvFileWithHeader:(BOOL)withHeader {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trip.csv"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];

    NSString *csvString;

    if (withHeader) {
        NSString *bundleVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
        NSArray <NSString *> *components = [bundleVersion componentsSeparatedByString:@"."];
        csvString = [NSString stringWithFormat:@"i%@#%ld#%ld\n",
                     components[0],
                     self.version,
                     self.AIVersion];

        csvString = [csvString stringByAppendingString:@"key,lat,lon,ts,bike,childCheckBox,trailerCheckBox,pLoc,incident,i1,i2,i3,i4,i5,i6,i7,i8,i9,scary,desc,i10\n"];
        [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

        NSInteger key = 0;
        for (TripLocation *tripLocation in self.tripLocations) {
            if (tripLocation.tripAnnotation) {
                NSString *comment;
                if (tripLocation.tripAnnotation.comment) {
                    comment = tripLocation.tripAnnotation.comment;
                    comment = [comment stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                    comment = [comment stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
                }
                csvString = [NSString stringWithFormat:@"%ld,%f,%f,%.0f,%ld,%d,%d,%ld,%ld,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%@,%d\n",
                             key,
                             tripLocation.location.coordinate.latitude,
                             tripLocation.location.coordinate.longitude,
                             tripLocation.location.timestamp.timeIntervalSince1970 * 1000.0,
                             self.bikeTypeId,
                             self.childseat,
                             self.trailer,
                             self.positionId,
                             tripLocation.tripAnnotation.incidentId,
                             tripLocation.tripAnnotation.bus,
                             tripLocation.tripAnnotation.bicycle,
                             tripLocation.tripAnnotation.pedestrian,
                             tripLocation.tripAnnotation.delivery,
                             tripLocation.tripAnnotation.commercial,
                             tripLocation.tripAnnotation.motorcycle,
                             tripLocation.tripAnnotation.car,
                             tripLocation.tripAnnotation.taxi,
                             tripLocation.tripAnnotation.other,
                             tripLocation.tripAnnotation.frightening,
                             comment ? [NSString stringWithFormat:@"\"%@\"", comment] : @"",
                             tripLocation.tripAnnotation.escooter];
                [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
                key++;
            }
        }

        csvString = @"\n===================\n";
        [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    }

    csvString = [NSString stringWithFormat:@"i%@#%ld\n",
                 [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                 self.version];
    csvString = [csvString stringByAppendingString:@"lat,lon,X,Y,Z,timeStamp,acc,a,b,c,obsDistanceLeft1,obsDistanceLeft2,obsDistanceRight1,obsDistanceRight2,obsClosePassEvent,XL,YL,ZL,RX,RY,RZ,RC\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableDictionary <NSNumber *, NSString *> *locationLines = [[NSMutableDictionary alloc] init];
    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;
        CLLocationAccuracy horizontalAccuracy = tripLocation.location.horizontalAccuracy;
        TripGyro *gyro = tripLocation.gyro;

        csvString = [NSString stringWithFormat:@"%f,%f,",
                     lat,
                     lon];

        csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%.0f,",
                     0.0,
                     0.0,
                     0.0,
                     tripLocation.location.timestamp.timeIntervalSince1970 * 1000.0];

        if (horizontalAccuracy == -1.0) {
            csvString = [csvString stringByAppendingString:@","];
        } else {
            csvString = [csvString stringByAppendingFormat:@"%f,",
                         horizontalAccuracy];
            horizontalAccuracy = -1;
        }

        if (!gyro) {
            csvString = [csvString stringByAppendingString:@",,,"];
        } else {
            csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,",
                         gyro.x,
                         gyro.y,
                         gyro.z];
            gyro = nil;
        }

        NSString *isClosePassEvent = @"0"; // means false
        NSString *leftSensorVal1 = @"";
        NSString *leftSensorVal2 = @"";
        NSString *rightSensorVal1 = @"";
        NSString *rightSensorVal2 = @"";

        if (tripLocation.closePassInfo != nil){
            isClosePassEvent = @"1";
            leftSensorVal1 = tripLocation.closePassInfo.leftSensor1Value.stringValue;
            leftSensorVal2 = tripLocation.closePassInfo.leftSensor2Value.stringValue;
            rightSensorVal1 = tripLocation.closePassInfo.rightSensor1Value.stringValue;
            rightSensorVal2 = tripLocation.closePassInfo.rightSensor2Value.stringValue;
        }

        csvString = [csvString stringByAppendingFormat:@"%@,%@,%@,%@,%@",leftSensorVal1,leftSensorVal2,rightSensorVal1,rightSensorVal2,isClosePassEvent]; // OBS Values
        csvString = [csvString stringByAppendingString:@",,,,,,"]; // Linear Giro Values
        csvString = [csvString stringByAppendingString:@"\n"];

        NSNumber *locationTime = [NSNumber numberWithDouble:tripLocation.location.timestamp.timeIntervalSince1970 * 1000.0];

        locationLines[locationTime] = csvString;
    }

    for (TripLocation *tripLocation in self.tripLocations) {
        for (TripMotion *tripMotion in tripLocation.tripMotions) {
            csvString = @",,";

            csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%.0f,",
                         tripMotion.x * 9.81,
                         tripMotion.y * 9.81,
                         tripMotion.z * 9.81,
                         tripMotion.timestamp * 1000.0];

            csvString = [csvString stringByAppendingString:@","];

            csvString = [csvString stringByAppendingString:@",,,"];
            csvString = [csvString stringByAppendingString:@",,,,,"]; // OBS Values
            csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%f,%f,%f,%f",
                         tripMotion.xl * 9.81,
                         tripMotion.yl * 9.81,
                         tripMotion.zl * 9.81,
                         tripMotion.xr,
                         tripMotion.yr,
                         tripMotion.zr,
                         tripMotion.cr];

            csvString = [csvString stringByAppendingString:@"\n"];
            NSNumber *motionTime = [NSNumber numberWithDouble:tripMotion.timestamp * 1000.0];

            while (locationLines.count > 0) {
                NSNumber *locationTime = [locationLines.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject;
                if (locationTime.doubleValue < motionTime.doubleValue) {
                    [fh writeData:[locationLines[locationTime] dataUsingEncoding:NSUTF8StringEncoding]];
                    [locationLines removeObjectForKey:locationTime];
                } else {
                    break;
                }
            }
            [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    [fh closeFile];
    return fileURL;
}

- (NSURL *)gpxFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trip.gpx"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];

    NSString *csvString;

    csvString = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    csvString = @"<gpx version=\"1.1\" creator=\"SimRa iOS\"><trk><trkseg>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;

        csvString = [NSString stringWithFormat:@"<trkpt lat=\"%f\" lon=\"%f\"></trkpt>\n",
                     lat,
                     lon];
        [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    }

    csvString = @"</trkseg></trk></gpx>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    [fh closeFile];
    return fileURL;
}

- (NSURL *)geoJSONFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trip.geojson"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];

    NSString *csvString;
    BOOL separator = FALSE;

    csvString = @"{\"type\":\"LineString\",\"coordinates\":[\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;

        csvString = [NSString stringWithFormat:@"%@[%f,%f]\n",
                     separator ? @"," : @"",
                     lon,
                     lat];
        separator = TRUE;
        [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    }

    csvString = @"]}\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    [fh closeFile];
    return fileURL;
}

- (NSURL *)kmlFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trip.kml"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];

    NSString *csvString;

    csvString = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    csvString = @"<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Document><Placemark id=\"Simra\"><LineString id=\"Simra\"><coordinates>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;

        csvString = [NSString stringWithFormat:@"%f,%f\n",
                     lon,
                     lat];
        [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    }

    csvString = @"</coordinates></LineString></Placemark></Document></kml>\n";
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];

    [fh closeFile];
    return fileURL;
}


- (void)startRecording {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    self.deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
    self.deferredMeters = [ad.defaults integerForKey:@"deferredMeters"];
    self.bikeTypeId = [ad.defaults integerForKey:@"bikeTypeId"];
    self.positionId = [ad.defaults integerForKey:@"positionId"];
    self.childseat = [ad.defaults integerForKey:@"childSeat"];
    self.trailer = [ad.defaults boolForKey:@"trailer"];

    if (ad.mm.isGyroAvailable) {
        [ad.mm startGyroUpdates];
    } else {
        NSLog(@"no isGyroAvailable");
    }

    ad.lm.delegate = self;
    if (CLLocationManager.locationServicesEnabled) {
        ad.lm.allowsBackgroundLocationUpdates = TRUE;
        ad.lm.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        ad.lm.activityType = CLActivityTypeFitness;
        [ad.lm startUpdatingLocation];
    } else {
        NSLog(@"no locationServicesEnabled");
    }

    if (ad.mm.isAccelerometerAvailable) {

#define ACCELEROMETER_SAMPLES 30
#define ACCELEROMETER_STEPS 5

        static double xa[ACCELEROMETER_SAMPLES];
        static double ya[ACCELEROMETER_SAMPLES];
        static double za[ACCELEROMETER_SAMPLES];
        static double xla[ACCELEROMETER_SAMPLES];
        static double yla[ACCELEROMETER_SAMPLES];
        static double zla[ACCELEROMETER_SAMPLES];
        static double xra[ACCELEROMETER_SAMPLES];
        static double yra[ACCELEROMETER_SAMPLES];
        static double zra[ACCELEROMETER_SAMPLES];
        static double cra[ACCELEROMETER_SAMPLES];
        static int aIndex;
        static int aFill;

        aIndex = 0;
        aFill = 0;
        ad.mm.accelerometerUpdateInterval = 1.0 / 50.0;
        [ad.mm startAccelerometerUpdates];
        if (ad.mm.isDeviceMotionAvailable) {
            ad.mm.deviceMotionUpdateInterval = 1.0 / 50.0;
            [ad.mm startDeviceMotionUpdates];
        }
        self.timer =
        [NSTimer
         scheduledTimerWithTimeInterval:1.0 / 50.0
         repeats:TRUE
         block:^(NSTimer * _Nonnull timer) {
            CMAccelerometerData *accelerometerData = ad.mm.accelerometerData;
            CMDeviceMotion *deviceMotion = ad.mm.deviceMotion;

            if (accelerometerData) {
                xa[aIndex] = accelerometerData.acceleration.x;
                ya[aIndex] = accelerometerData.acceleration.y;
                za[aIndex] = accelerometerData.acceleration.z;
                if (deviceMotion) {
                    xla[aIndex] = deviceMotion.userAcceleration.x;
                    yla[aIndex] = deviceMotion.userAcceleration.y;
                    zla[aIndex] = deviceMotion.userAcceleration.z;
                    xra[aIndex] = deviceMotion.attitude.quaternion.x;
                    yra[aIndex] = deviceMotion.attitude.quaternion.y;
                    zra[aIndex] = deviceMotion.attitude.quaternion.z;
                    cra[aIndex] = deviceMotion.attitude.quaternion.w;
                } else {
                    xla[aIndex] = 0.0;
                    yla[aIndex] = 0.0;
                    zla[aIndex] = 0.0;
                    xra[aIndex] = 0.0;
                    yra[aIndex] = 0.0;
                    zra[aIndex] = 0.0;
                    cra[aIndex] = 0.0;
                }

                aIndex = (aIndex + 1) % ACCELEROMETER_SAMPLES;
                aFill++;

                if (aFill >= ACCELEROMETER_SAMPLES) {
                    double x = 0.0;
                    double y = 0.0;
                    double z = 0.0;
                    double xl = 0.0;
                    double yl = 0.0;
                    double zl = 0.0;
                    double xr = 0.0;
                    double yr = 0.0;
                    double zr = 0.0;
                    double cr = 0.0;
                    for (int i = 0; i < ACCELEROMETER_SAMPLES; i++) {
                        x += xa[i];
                        y += ya[i];
                        z += za[i];
                        xl += xla[i];
                        yl += yla[i];
                        zl += zla[i];
                        xr += xla[i];
                        yr += yla[i];
                        zr += zla[i];
                        cr += zla[i];
                    }
                    x /= ACCELEROMETER_SAMPLES;
                    y /= ACCELEROMETER_SAMPLES;
                    z /= ACCELEROMETER_SAMPLES;
                    xl /= ACCELEROMETER_SAMPLES;
                    yl /= ACCELEROMETER_SAMPLES;
                    zl /= ACCELEROMETER_SAMPLES;
                    xr /= ACCELEROMETER_SAMPLES;
                    yr /= ACCELEROMETER_SAMPLES;
                    zr /= ACCELEROMETER_SAMPLES;
                    cr /= ACCELEROMETER_SAMPLES;

                    [self addAccelerationX:x y:y z:z xl:xl yl:yl zl:zl xr:xr yr:yr zr:zr cr:cr];
                    aFill = ACCELEROMETER_SAMPLES - ACCELEROMETER_STEPS;
                }
            } else {
                NSLog(@"error no Data");
            }
        }];
    } else {
        NSLog(@"no isAccelerometerAvailable");
    }
}

- (void)stopRecording {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [self.timer invalidate];
    if (ad.mm.isGyroActive) {
        [ad.mm stopGyroUpdates];
    }
    if (ad.mm.isAccelerometerActive) {
        [ad.mm stopAccelerometerUpdates];
    }
    if (ad.mm.isDeviceMotionActive) {
        [ad.mm stopDeviceMotionUpdates];
    }
    [ad.lm stopUpdatingLocation];
    ad.lm.delegate = nil;

    if ([ad.defaults boolForKey:@"AI"]) {
        [self AIIncidentDetection];
    } else {
        //        if (![BluetoothManager getInstance].connected){
        [self offlineIncidentDectection];
        //        }
    }
    for ( int i = 0; i < _tripLocations.count; i++){
        TripLocation *tripLoc = _tripLocations[i];
        if (tripLoc.closePassInfo != nil){
            NSLog(@"%f Lat", tripLoc.location.coordinate.latitude);
            NSLog(@"%f long", tripLoc.location.coordinate.longitude);

            TripAnnotation *tripAnnotation = [[TripAnnotation alloc] init];
            tripAnnotation.incidentId = 1;
            tripAnnotation.comment = [NSString stringWithFormat:@"Open Bike Sensor Close Pass incident reading\n Left Sensor: %@\n Right Sensor: %@\n", tripLoc.closePassInfo.leftSensorValue, tripLoc.closePassInfo.rightSensorValue];
            //            self.tripLocations.lastObject.tripAnnotation = tripAnnotation;
            _tripLocations[i].tripAnnotation = tripAnnotation;
        }
    }

    [self save];
}

- (void)addLocation:(CLLocation *)location withGyroData:(CMGyroData *)gyroData {
    if (!self.startLocation) {
        self.startLocation = location;
    }

    AppDelegate *ad = [AppDelegate sharedDelegate];
    NSInteger deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
    NSInteger deferredMeters = [ad.defaults integerForKey:@"deferredMeters"];
    if ((deferredSecs == 0 || [[NSDate alloc] init].timeIntervalSince1970 - self.startLocation.timestamp.timeIntervalSince1970 > deferredSecs) &&
        (deferredMeters == 0 || [location distanceFromLocation:self.startLocation] > deferredMeters)) {
        TripLocation *newLocation = [[TripLocation alloc] init];
        newLocation.location = location;
        TripGyro *gyro = [[TripGyro alloc] init];
        gyro.x = gyroData.rotationRate.x;
        gyro.y = gyroData.rotationRate.y;
        gyro.z = gyroData.rotationRate.z;
        newLocation.gyro = gyro;
        [self.tripLocations addObject:newLocation];
    }
}

- (void)addAccelerationX:(double)x
                       y:(double)y
                       z:(double)z
                      xl:(double)xl
                      yl:(double)yl
                      zl:(double)zl
                      xr:(double)xr
                      yr:(double)yr
                      zr:(double)zr
                      cr:(double)cr {
    TripLocation *lastLocation = self.tripLocations.lastObject;
    if (lastLocation) {
        TripMotion *tripMotion = [[TripMotion alloc] init];
        tripMotion.x = x;
        tripMotion.y = y;
        tripMotion.z = z;
        tripMotion.xl = xl;
        tripMotion.yl = yl;
        tripMotion.zl = zl;
        tripMotion.xr = xr;
        tripMotion.yr = yr;
        tripMotion.zr = zr;
        tripMotion.cr = cr;
        tripMotion.timestamp = [NSDate date].timeIntervalSince1970;
        [lastLocation.tripMotions addObject:tripMotion];
        self.lastTripMotion = tripMotion;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
#define LOCATION_FREQUENCE 3.0

    for (CLLocation *location in locations) {
        //NSLog(@"[Trip] didUpdateLocations %f %@",
        //  location.timestamp.timeIntervalSince1970, location);
        if (!self.lastLocation ||
            location.timestamp.timeIntervalSince1970 - self.lastLocation.timestamp.timeIntervalSince1970 >= LOCATION_FREQUENCE) {

            AppDelegate *ad = [AppDelegate sharedDelegate];
            CMGyroData *gyroData = ad.mm.gyroData;

            NSLog(@"[Trip] addLocation:%@ withGyroData:%@", location, gyroData);
            [self addLocation:location withGyroData:gyroData];
            self.lastLocation = location;
        }
    }
}

- (NSInteger)tripAnnotations {
    NSInteger tripAnnotations = 0;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (tripLocation.tripAnnotation) {
            tripAnnotations++;
        }
    }
    return tripAnnotations;
}

- (NSInteger)tripValidAnnotations {
    NSInteger tripValidAnnotations = 0;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (tripLocation.tripAnnotation) {
            if (tripLocation.tripAnnotation.incidentId != 0)
                tripValidAnnotations++;
        }
    }
    return tripValidAnnotations;
}

- (NSInteger)numberOfScary {
    NSInteger numberOfScary = 0;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (tripLocation.tripAnnotation) {
            if (tripLocation.tripAnnotation.frightening) {
                numberOfScary++;
            }
        }
    }
    return numberOfScary;

}

- (NSDateInterval *)duration {
    NSDateInterval *duration;
    NSDate *start = self.tripLocations.firstObject.location.timestamp;
    NSDate *end = self.tripLocations.lastObject.location.timestamp;
    if (start && end) {
        duration = [[NSDateInterval alloc] initWithStartDate: start endDate: end];
    }
    return duration;
}

- (NSInteger)length {
    NSInteger length = 0;
    TripLocation *lastTripLocation;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (!lastTripLocation) {
            lastTripLocation = tripLocation;
        } else {
            length += [tripLocation.location distanceFromLocation:lastTripLocation.location];
            lastTripLocation = tripLocation;
        }
    }
    return length;
}

- (NSInteger)idle {
    NSInteger idle = 0;

    TripLocation *lastTripLocation;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (!lastTripLocation) {
            lastTripLocation = tripLocation;
        } else {
            // idle when travelling with less than 3 km/h. speed is given in m/s)
            if (tripLocation.location.speed < 3.0 / 3.6) {
                idle += (tripLocation.location.timestamp.timeIntervalSince1970 -
                         lastTripLocation.location.timestamp.timeIntervalSince1970);
            }
            lastTripLocation = tripLocation;
        }
    }

    return idle;
}
// comes here first
- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    AppDelegate *ad = [AppDelegate sharedDelegate];

    BOOL saveNecessary = FALSE;
    // remove unedited annotations
    for (TripLocation *location in self.tripLocations) {
        if (location.tripAnnotation && location.tripAnnotation.incidentId == 0) {
            location.tripAnnotation = nil;
            saveNecessary = TRUE;
        }
    }

    // if no valid annotations, insert dummy
    if (!self.tripAnnotations) {
        TripLocation *location = self.tripLocations.firstObject;
        TripAnnotation *annotation = [[TripAnnotation alloc] init];
        annotation.incidentId = -5;
        location.tripAnnotation = annotation;
        saveNecessary = TRUE;
    }

    if (saveNecessary) {
        [self save];
    }

    if (!self.statisticsAdded) {
        [ad.trips addTripToStatistics:self];
        self.statisticsAdded = TRUE;
        [self save];
    }

    [super uploadFile:name WithController:controller error:error completion:completion];
}

- (void)successfullyReUploaded {
    self.reUploaded = TRUE;
}

- (void)save {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.trips updateTrip:self];

    // Store in FileSystem
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [fileManager URLsForDirectory:NSDocumentDirectory
                                                      inDomains:NSUserDomainMask].firstObject;
    NSURL *tripURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Trip-%ld.json", self.identifier]];
    NSURL *tripInfoURL = [documentDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"TripInfo-%ld.json", self.identifier]];

    BOOL tripSuccess = [fileManager createFileAtPath:tripURL.path
                                            contents:self.asJSONData
                                          attributes:nil];
    BOOL tripInfoSuccess = [fileManager createFileAtPath:tripInfoURL.path
                                                contents:self.tripInfo.asJSONData
                                              attributes:nil];

    NSLog(@"[Trip] save tripSuccess=%d tripInfoSuccess=%d",
          tripSuccess, tripInfoSuccess);

    // Delete from UserDefaults
#if 0
    NSDictionary *tripDict = self.asDictionary;
    //    [ad.defaults setObject:tripDict forKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier]];
    //    [Utility saveIntWithKey:@"lastTripId" value:1];
    [Utility saveWithKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier] value:tripDict];
    NSDictionary *tripInfoDict = self.tripInfo.asDictionary;
    //    [ad.defaults setObject:tripInfoDict forKey:[NSString stringWithFormat:@"TripInfo-%ld", self.identifier]];
    [Utility saveWithKey:[NSString stringWithFormat:@"TripInfo-%ld", self.identifier] value:tripInfoDict];

#else
    [Utility removeWithKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier]];
    [Utility removeWithKey:[NSString stringWithFormat:@"TripInfo-%ld", self.identifier]];

    //    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier]];
    //    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"TripInfo-%ld", self.identifier]];
#endif
}

- (TripInfo *)tripInfo {
    TripInfo *tripInfo = [[TripInfo alloc] init];
    tripInfo.identifier = self.identifier;
    tripInfo.version = self.version;
    tripInfo.edited = self.edited;
    tripInfo.uploaded = self.uploaded;
    tripInfo.fileHash = self.fileHash;
    tripInfo.filePasswd = self.filePasswd;
    tripInfo.duration = self.duration;
    tripInfo.length = self.length;
    tripInfo.statisticsAdded = self.statisticsAdded;
    tripInfo.reUploaded = self.reUploaded;
    tripInfo.annotationsCount = self.tripAnnotations;
    tripInfo.validAnnotationsCount = self.tripValidAnnotations;
    return tripInfo;
}

- (void)offlineIncidentDectection {
    TripLocation *largestXMotion;
    TripLocation *secondLargestXMotion;
    TripLocation *largestYMotion;
    TripLocation *secondLargestYMotion;
    TripLocation *largestZMotion;
    TripLocation *secondLargestZMotion;

    double largestX = 0.0;
    double secondLargestX = 0.0;
    double largestY = 0.0;
    double secondLargestY = 0.0;
    double largestZ = 0.0;
    double secondLargestZ = 0.0;

    for (TripLocation *tripLocation in self.tripLocations) {
        if (tripLocation == self.tripLocations.firstObject ||
            tripLocation == self.tripLocations.lastObject) {
            continue;
        }
        CMAcceleration minMax = tripLocation.minMaxOfMotions;
        if (minMax.x > largestX) {
            secondLargestXMotion = largestXMotion;
            secondLargestX = largestX;
            largestXMotion = tripLocation;
            largestX = minMax.x;
        } else if (minMax.x > secondLargestX) {
            secondLargestXMotion = tripLocation;
            secondLargestX = minMax.x;
        }
        if (minMax.y > largestY) {
            secondLargestYMotion = largestYMotion;
            secondLargestY = largestY;
            largestYMotion = tripLocation;
            largestY = minMax.y;
        } else if (minMax.y > secondLargestY) {
            secondLargestYMotion = tripLocation;
            secondLargestY = minMax.y;
        }
        if (minMax.z > largestZ) {
            secondLargestZMotion = largestZMotion;
            secondLargestZ = largestZ;
            largestZMotion = tripLocation;
            largestZ = minMax.z;
        } else if (minMax.z > secondLargestZ) {
            secondLargestZMotion = tripLocation;
            secondLargestZ = minMax.z;
        }
    }
    largestXMotion.tripAnnotation = [[TripAnnotation alloc] init];
    secondLargestXMotion.tripAnnotation = [[TripAnnotation alloc] init];
    largestYMotion.tripAnnotation = [[TripAnnotation alloc] init];
    secondLargestYMotion.tripAnnotation = [[TripAnnotation alloc] init];
    largestZMotion.tripAnnotation = [[TripAnnotation alloc] init];
    secondLargestZMotion.tripAnnotation = [[TripAnnotation alloc] init];
}

- (void)AIIncidentDetection {
    __block BOOL finished = FALSE;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    urlString = [NSString stringWithFormat:@"%@/classify-ride-cyclesense?clientHash=%@&os=iOS",
                 API.APIPrefix,
                 NSString.clientHash];
    [request setHTTPMethod:@"POST"];
    [request setURL:[NSURL URLWithString:urlString]];

    [request setValue:@"text/plain" forHTTPHeaderField: @"Content-Type"];
    [request setTimeoutInterval:10.0];
    NSLog(@"AIIncidentDetection request:\n%@", request);
    NSURL *csvFile = [self csvFileWithHeader:FALSE];

    NSURLSessionUploadTask *dataTask =
    [
        [NSURLSession sharedSession]
        uploadTaskWithRequest:request
        fromFile:csvFile
        completionHandler:^(NSData *data,
                            NSURLResponse *response,
                            NSError *connectionError) {

                                NSError *fmError;
                                [[NSFileManager defaultManager] removeItemAtURL:csvFile error:&fmError];

                                if (connectionError) {
                                    NSLog(@"AIIncidentDetection connectionError %@", connectionError);
                                    [self offlineIncidentDectection];
                                    finished = TRUE;
                                } else {
                                    NSLog(@" AIIncidentDetection response %@ %@",
                                          response,
                                          [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

                                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                        if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                                            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                            if (array && array.count > 0) {
                                                NSNumber *AIVersion = array[0];
                                                self.AIVersion = AIVersion.integerValue;
                                                for (NSInteger i = 1; i < array.count; i++) {
                                                    NSNumber *interval = array[i];
                                                    for (TripLocation *tripLocation in self.tripLocations) {
                                                        if (round(tripLocation.location.timestamp.timeIntervalSince1970 * 1000.0) == interval.doubleValue) {
                                                            if (!tripLocation.tripAnnotation) {
                                                                tripLocation.tripAnnotation = [[TripAnnotation alloc] init];
                                                            }
                                                            break;
                                                        }
                                                        for (TripMotion *tripMotion in tripLocation.tripMotions) {
                                                            if (round(tripMotion.timestamp * 1000.0) == interval.doubleValue) {
                                                                if (!tripLocation.tripAnnotation) {
                                                                    tripLocation.tripAnnotation = [[TripAnnotation alloc] init];
                                                                }
                                                                break;
                                                            }
                                                        }
                                                    }
                                                }
                                            } else {
                                                [self offlineIncidentDectection];
                                            }
                                            finished = TRUE;
                                        } else {
                                            [self offlineIncidentDectection];
                                            finished = TRUE;
                                        }
                                    } else {
                                        [self offlineIncidentDectection];
                                        finished = TRUE;
                                    }
                                }
                            }];

    [dataTask resume];

    while (!finished) {
        NSLog(@"AIIncidentDetection waiting to finish");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

@end
