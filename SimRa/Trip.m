//
//  Trip.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Trip.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"

@implementation TripAnnotation
@end

@implementation TripMotion
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

@interface Trip ()
@property (nonatomic) NSInteger identifier;
@property (nonatomic) Boolean recording;
@property (strong, nonatomic) CLLocation *startLocation;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) TripMotion *lastTripMotion;
@property (nonatomic) NSInteger deferredSecs;
@property (nonatomic) NSInteger deferredMeters;
@property (nonatomic) NSInteger bikeTypeId;
@property (nonatomic) NSInteger positionId;
@property (nonatomic) Boolean childseat;
@property (nonatomic) Boolean trailer;

#define ACCERELOMETER_SAMPLES 30
@property (strong, nonatomic) NSMutableArray <CMAccelerometerData *> *accelerometerDataArray;

#define LOCATION_FREQUENCE 3.0

@end

@implementation Trip
- (instancetype)init {
    self = [super init];
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSInteger identifier = [ad.defaults integerForKey:@"lastTripId"];
    identifier ++;
    self.identifier = identifier;
    [ad.defaults setInteger:identifier forKey:@"lastTripId"];
        
    self.recording = FALSE;
    self.edited = FALSE;
    self.tripLocations = [[NSMutableArray alloc] init];
    return self;
}

- (instancetype)initFromDictionary:(NSDictionary *)dict {
    self = [super init];
    NSNumber *identifier = [dict objectForKey:@"identifier"];
    self.identifier = identifier.integerValue;
    NSNumber *version = [dict objectForKey:@"version"];
    self.version = version.integerValue;
    NSNumber *recording = [dict objectForKey:@"recording"];
    self.recording = recording.boolValue;
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
    NSNumber *deferredSecs = [dict objectForKey:@"deferredSecs"];
    self.deferredSecs = deferredSecs.integerValue;
    NSNumber *deferredMeters = [dict objectForKey:@"deferredMeters"];
    self.deferredMeters = deferredMeters.integerValue;
    
    NSNumber *childseat = [dict objectForKey:@"childseat"];
    self.childseat = childseat.boolValue;
    NSNumber *trailer = [dict objectForKey:@"trailer"];
    self.trailer = trailer.boolValue;
    
    self.tripLocations = [[NSMutableArray alloc] init];
    
    
    NSArray *tripLocations = [dict objectForKey:@"tripLocations"];
    for (NSDictionary *tripLocationDict in tripLocations) {
        NSNumber *timestamp = [tripLocationDict objectForKey:@"timestamp"];
        NSNumber *lat = [tripLocationDict objectForKey:@"lat"];
        NSNumber *lon = [tripLocationDict objectForKey:@"lon"];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat.doubleValue,
                                                                       lon.doubleValue);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:coordinate
                                altitude:-1
                                horizontalAccuracy:-1
                                verticalAccuracy:-1
                                course:-1
                                speed:-1
                                timestamp:[NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue]];
        TripLocation *tripLocation = [[TripLocation alloc] init];
        tripLocation.location = location;
        tripLocation.tripMotions = [[NSMutableArray alloc] init];
        NSDictionary *tripMotionsArray = [tripLocationDict objectForKey:@"tripMotions"];
        for (NSDictionary *tripMotionDict in tripMotionsArray) {
            TripMotion *tripMotion = [[TripMotion alloc] init];
            NSNumber *x = [tripMotionDict objectForKey:@"x"];
            NSNumber *y = [tripMotionDict objectForKey:@"y"];
            NSNumber *z = [tripMotionDict objectForKey:@"z"];
            NSNumber *timestamp = [tripMotionDict objectForKey:@"timestamp"];
            tripMotion.x = x.doubleValue;
            tripMotion.y = y.doubleValue;
            tripMotion.z = z.doubleValue;
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
            NSString *comment = [tripAnnotationDict objectForKey:@"comment"];
            tripAnnotation.comment = comment;
            
            tripLocation.tripAnnotation = tripAnnotation;
        }
        [self.tripLocations addObject:tripLocation];
    }
    return self;
}

- (NSDictionary *)asDictionary {
    NSMutableDictionary *tripDict = [[NSMutableDictionary alloc] init];
    [tripDict setObject:[NSNumber numberWithInteger:self.identifier] forKey:@"identifier"];
    [tripDict setObject:[NSNumber numberWithInteger:self.version] forKey:@"version"];
    [tripDict setObject:[NSNumber numberWithBool:self.recording] forKey:@"recording"];
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
    
    [tripDict setObject:[NSNumber numberWithBool:self.childseat] forKey:@"childseat"];
    [tripDict setObject:[NSNumber numberWithBool:self.trailer] forKey:@"trailer"];
    
    NSMutableArray *tripLocationsArray = [[NSMutableArray alloc] init];
    for (TripLocation *tripLocation in self.tripLocations) {
        NSMutableDictionary *tripLocationDict = [[NSMutableDictionary alloc] init];
        [tripLocationDict
         setObject:[NSNumber numberWithDouble:tripLocation.location.timestamp.timeIntervalSince1970]
         forKey:@"timestamp"];
        [tripLocationDict
         setObject:[NSNumber numberWithDouble: tripLocation.location.coordinate.latitude]
         forKey:@"lat"];
        [tripLocationDict
         setObject:[NSNumber numberWithDouble: tripLocation.location.coordinate.longitude]
         forKey:@"lon"];
        
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
            
            if (tripLocation.tripAnnotation.comment) {
                [tripAnnotationDict
                 setObject:tripLocation.tripAnnotation.comment
                 forKey:@"comment"];
            }
            
            [tripLocationDict setObject:tripAnnotationDict forKey:@"tripAnnotation"];
        }
        
        [tripLocationsArray addObject:tripLocationDict];
    }
    [tripDict setObject:tripLocationsArray forKey:@"tripLocations"];
    return tripDict;
}

- (NSURL *)csvFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trip.csv"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];
    
    NSString *csvString;
    
    csvString = [NSString stringWithFormat:@"i%@#%ld\n",
                 [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                 self.version];
    csvString = [csvString stringByAppendingString:@"key,lat,lon,ts,bike,childCheckBox,trailerCheckBox,pLoc,incident,i1,i2,i3,i4,i5,i6,i7,i8,i9,scary,desc\n"];
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
            csvString = [NSString stringWithFormat:@"%ld,%f,%f,%.0f,%ld,%d,%d,%ld,%ld,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%@\n",
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
                         comment ? [NSString stringWithFormat:@"\"%@\"", comment] : @""];
            [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
            key++;
        }
    }
    
    csvString = @"\n===================\n";
    csvString = [csvString stringByAppendingFormat:@"i%@#%ld\n",
                 [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                 self.version];
    csvString = [csvString stringByAppendingString:@"lat,lon,X,Y,Z,timeStamp\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    
    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;
        for (TripMotion *tripMotion in tripLocation.tripMotions) {
            if (lat == 0.0 && lon == 0.0) {
                csvString = @",,";
            } else {
                csvString = [NSString stringWithFormat:@"%f,%f,",
                             lat,
                             lon];
                lat = 0.0;
                lon = 0.0;
            }
            csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%.0f\n",
                         tripMotion.x * 9.81,
                         tripMotion.y * 9.81,
                         tripMotion.z * 9.81,
                         tripMotion.timestamp * 1000.0];
            [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    [fh closeFile];
    return fileURL;
}

- (void)startRecording {
    if (!self.recording) {
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        self.deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
        self.deferredMeters = [ad.defaults integerForKey:@"deferredSecs"];
        self.bikeTypeId = [ad.defaults integerForKey:@"bikeTypeId"];
        self.positionId = [ad.defaults integerForKey:@"positionId"];
        self.childseat = [ad.defaults integerForKey:@"childseat"];
        self.trailer = [ad.defaults boolForKey:@"trailer"];
        self.accelerometerDataArray = [[NSMutableArray alloc] init];
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
            ad.mm.accelerometerUpdateInterval = 1.0 / 50.0;
            NSOperationQueue *oq = [[NSOperationQueue alloc] init];
            [ad.mm startAccelerometerUpdatesToQueue:oq withHandler:
             ^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
                 if (!error) {
                     //NSLog(@"CMAccelerometerData %@", accelerometerData);
                     
                     [self.accelerometerDataArray addObject:accelerometerData];
                     if (self.accelerometerDataArray.count == ACCERELOMETER_SAMPLES) {
                         CMAcceleration avgAcceleration;
                         avgAcceleration.x = 0;
                         avgAcceleration.y = 0;
                         avgAcceleration.z = 0;
                         for (CMAccelerometerData *accelerometerData in self.accelerometerDataArray) {
                             avgAcceleration.x += accelerometerData.acceleration.x;
                             avgAcceleration.y += accelerometerData.acceleration.y;
                             avgAcceleration.z += accelerometerData.acceleration.z;
                         }
                         avgAcceleration.x /= ACCERELOMETER_SAMPLES;
                         avgAcceleration.y /= ACCERELOMETER_SAMPLES;
                         avgAcceleration.z /= ACCERELOMETER_SAMPLES;
                         
                         [self addAccelerationX:avgAcceleration.x
                                              y:avgAcceleration.y
                                              z:avgAcceleration.z];
                         
                         [self.accelerometerDataArray removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 5)]];
                     }
                 } else {
                     NSLog(@"error %@", error);
                 }
             }];
        } else {
            NSLog(@"no isAccelerometerAvailable");
        }
        
        self.recording = TRUE;
    }
}

- (void)stopRecording {
    if (self.recording) {
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.mm stopAccelerometerUpdates];
        [ad.lm stopUpdatingLocation];
        ad.lm.delegate = nil;
        self.recording = FALSE;

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

        [self save];
    }
}

- (void)addLocation:(CLLocation *)location {
    if (!self.startLocation) {
        self.startLocation = location;
    }
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSInteger deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
    NSInteger deferredMeters = [ad.defaults integerForKey:@"deferredMeters"];
    if ((deferredSecs == 0 || [[NSDate alloc] init].timeIntervalSince1970 - self.startLocation.timestamp.timeIntervalSince1970 > deferredSecs) &&
        (deferredMeters == 0 || [location distanceFromLocation:self.startLocation] > deferredMeters)) {
        TripLocation *newLocation = [[TripLocation alloc] init];
        newLocation.location = location;
        [self.tripLocations addObject:newLocation];
    }
}

- (void)addAccelerationX:(double)x
                       y:(double)y
                       z:(double)z {
    TripLocation *lastLocation = self.tripLocations.lastObject;
    if (lastLocation) {
        TripMotion *tripMotion = [[TripMotion alloc] init];
        tripMotion.x = x;
        tripMotion.y = y;
        tripMotion.z = z;
        tripMotion.timestamp = [NSDate date].timeIntervalSince1970;
        [lastLocation.tripMotions addObject:tripMotion];
        self.lastTripMotion = tripMotion;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *location in locations) {
        NSLog(@"[Trip] didUpdateLocations %f %@", location.timestamp.timeIntervalSince1970, location);
        if (!self.lastLocation ||
            location.timestamp.timeIntervalSince1970 - self.lastLocation.timestamp.timeIntervalSince1970 >= LOCATION_FREQUENCE) {
            NSLog(@"[Trip] addLocation %@", location);
            [self addLocation:location];
            self.lastLocation = location;
        }
    }
}

- (NSInteger)tripMotions {
    NSInteger tripMotions = 0;
    for (TripLocation *tripLocation in self.tripLocations) {
        tripMotions += tripLocation.tripMotions.count;
    }
    return tripMotions;
}

- (NSInteger)tripAnnotations {
    NSInteger tripAnnotations = 0;
    for (TripLocation *tripLocation in self.tripLocations) {
        if (tripLocation.tripAnnotation) {
            tripAnnotations ++;
        }
    }
    return tripAnnotations;
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
    
    return idle;
}

- (void)uploadWithController:(id)controller error:(SEL)error completion:(SEL)completion {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.trips addTripToStatistics:self];

    [super uploadWithController:controller error:error completion:completion];
}

- (void)edit {
    self.edited = TRUE;
    [self save];
}

- (void)save {
    NSDictionary *tripDict = self.asDictionary;
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setObject:tripDict forKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier]];
}

@end
