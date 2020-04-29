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
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSInteger identifier = [ad.defaults integerForKey:@"lastTripId"];
    identifier ++;
    self.identifier = identifier;
    [ad.defaults setInteger:identifier forKey:@"lastTripId"];
    
    self.edited = FALSE;
    self.uploaded = FALSE;
    self.statisticsAdded = FALSE;
    self.reUploaded = FALSE;
    self.tripLocations = [[NSMutableArray alloc] init];
    return self;
}

- (instancetype)initFromDefaults:(NSInteger)identifier {
    NSLog(@"initFromDefaults %ld", identifier);
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSDictionary *dict = [ad.defaults objectForKey:[NSString stringWithFormat:@"Trip-%ld",
                                                    identifier]];
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
    NSNumber *statisticsAdded = [dict objectForKey:@"statisticsAdded"];
    self.statisticsAdded = statisticsAdded.boolValue;
    NSNumber *reUploaded = [dict objectForKey:@"reUploaded"];
    self.reUploaded = reUploaded.boolValue;

    self.tripLocations = [[NSMutableArray alloc] init];
    
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
        annotation.incidentId = 0;
        annotation.comment = @"k2y1";
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
    
    [tripDict setObject:[NSNumber numberWithBool:self.childseat] forKey:@"childseat"];
    [tripDict setObject:[NSNumber numberWithBool:self.trailer] forKey:@"trailer"];
    [tripDict setObject:[NSNumber numberWithBool:self.statisticsAdded] forKey:@"statisticsAdded"];
    [tripDict setObject:[NSNumber numberWithBool:self.reUploaded] forKey:@"reUploaded"];

    NSMutableArray *tripLocationsArray = [[NSMutableArray alloc] init];
    for (TripLocation *tripLocation in self.tripLocations) {
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

    NSString *bundleVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    NSArray <NSString *> *components = [bundleVersion componentsSeparatedByString:@"."];
    csvString = [NSString stringWithFormat:@"i%@#%ld\n",
                 components[0],
                 self.version];

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
    csvString = [csvString stringByAppendingFormat:@"i%@#%ld\n",
                 [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                 self.version];
    csvString = [csvString stringByAppendingString:@"lat,lon,X,Y,Z,timeStamp,acc,a,b,c\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    
    for (TripLocation *tripLocation in self.tripLocations) {
        CLLocationDegrees lat = tripLocation.location.coordinate.latitude;
        CLLocationDegrees lon = tripLocation.location.coordinate.longitude;
        CLLocationAccuracy horizontalAccuray = tripLocation.location.horizontalAccuracy;
        TripGyro *gyro = tripLocation.gyro;

        if (tripLocation.tripMotions.count > 0) {
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

                csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%.0f,",
                             tripMotion.x * 9.81,
                             tripMotion.y * 9.81,
                             tripMotion.z * 9.81,
                             tripMotion.timestamp * 1000.0];

                if (horizontalAccuray == -1.0) {
                    csvString = [csvString stringByAppendingString:@","];
                } else {
                    csvString = [csvString stringByAppendingFormat:@"%f,",
                                 horizontalAccuray];
                    horizontalAccuray = -1;
                }

                if (!gyro) {
                    csvString = [csvString stringByAppendingString:@",,\n"];
                } else {
                    csvString = [csvString stringByAppendingFormat:@"%f,%f,%f\n",
                                 gyro.x,
                                 gyro.y,
                                 gyro.z];
                    gyro = nil;
                }

                [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
            }
        } else {
            csvString = [NSString stringWithFormat:@"%f,%f,",
                         lat,
                         lon];

            csvString = [csvString stringByAppendingFormat:@"%f,%f,%f,%.0f,",
                         0.0,
                         0.0,
                         0.0,
                         tripLocation.location.timestamp.timeIntervalSince1970 * 1000.0];

            if (horizontalAccuray == -1.0) {
                csvString = [csvString stringByAppendingString:@","];
            } else {
                csvString = [csvString stringByAppendingFormat:@"%f,",
                             horizontalAccuray];
                horizontalAccuray = -1;
            }

            if (!gyro) {
                csvString = [csvString stringByAppendingString:@",,\n"];
            } else {
                csvString = [csvString stringByAppendingFormat:@"%f,%f,%f\n",
                             gyro.x,
                             gyro.y,
                             gyro.z];
                gyro = nil;
            }

            [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    [fh closeFile];
    return fileURL;
}

- (void)startRecording {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
    self.deferredMeters = [ad.defaults integerForKey:@"deferredSecs"];
    self.bikeTypeId = [ad.defaults integerForKey:@"bikeTypeId"];
    self.positionId = [ad.defaults integerForKey:@"positionId"];
    self.childseat = [ad.defaults integerForKey:@"childseat"];
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
        static int aIndex;
        static int aFill;

        aIndex = 0;
        aFill = 0;
        ad.mm.accelerometerUpdateInterval = 1.0 / 50.0;
        [ad.mm startAccelerometerUpdates];
        self.timer =
        [NSTimer
         scheduledTimerWithTimeInterval:1.0 / 50.0
         repeats:TRUE
         block:^(NSTimer * _Nonnull timer) {
             CMAccelerometerData *accelerometerData = ad.mm.accelerometerData;
             if (accelerometerData) {
                 xa[aIndex] = accelerometerData.acceleration.x;
                 ya[aIndex] = accelerometerData.acceleration.y;
                 za[aIndex] = accelerometerData.acceleration.z;
                 aIndex = (aIndex + 1) % ACCELEROMETER_SAMPLES;
                 aFill++;

                 if (aFill >= ACCELEROMETER_SAMPLES) {
                     double x = 0.0;
                     double y = 0.0;
                     double z = 0.0;
                     for (int i = 0; i < ACCELEROMETER_SAMPLES; i++) {
                         x += xa[i];
                         y += ya[i];
                         z += za[i];
                     }
                     x /= ACCELEROMETER_SAMPLES;
                     y /= ACCELEROMETER_SAMPLES;
                     z /= ACCELEROMETER_SAMPLES;

                     [self addAccelerationX:x y:y z:z];
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
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self.timer invalidate];
    if (ad.mm.isGyroActive) {
        [ad.mm stopGyroUpdates];
    }
    if (ad.mm.isAccelerometerActive) {
        [ad.mm stopAccelerometerUpdates];
    }
    [ad.lm stopUpdatingLocation];
    ad.lm.delegate = nil;
    
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
    
    [self save];
}

- (void)addLocation:(CLLocation *)location withGyroData:(CMGyroData *)gyroData {
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
#define LOCATION_FREQUENCE 3.0

    for (CLLocation *location in locations) {
        //NSLog(@"[Trip] didUpdateLocations %f %@",
        //  location.timestamp.timeIntervalSince1970, location);
        if (!self.lastLocation ||
            location.timestamp.timeIntervalSince1970 - self.lastLocation.timestamp.timeIntervalSince1970 >= LOCATION_FREQUENCE) {

            AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
            CMGyroData *gyroData = ad.mm.gyroData;

            NSLog(@"[Trip] addLocation:%@ withGyroData:%@", location, gyroData);
            [self addLocation:location withGyroData:gyroData];
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

- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

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
        annotation.incidentId = 0;
        annotation.comment = @"3fzr";
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
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSDictionary *tripDict = self.asDictionary;
    [ad.defaults setObject:tripDict forKey:[NSString stringWithFormat:@"Trip-%ld", self.identifier]];
    NSDictionary *tripInfoDict = self.tripInfo.asDictionary;
    [ad.defaults setObject:tripInfoDict forKey:[NSString stringWithFormat:@"TripInfo-%ld", self.identifier]];
    [ad.trips updateTrip:self];
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

@end
