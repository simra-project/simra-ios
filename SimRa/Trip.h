//
//  Trip.h
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import "UploaderObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface TripAnnotation : NSObject
@property (strong, nonatomic) NSString *comment;
@property (nonatomic) BOOL frightening;
@property (nonatomic) BOOL car;
@property (nonatomic) BOOL taxi;
@property (nonatomic) BOOL delivery;
@property (nonatomic) BOOL bus;
@property (nonatomic) BOOL commercial;
@property (nonatomic) BOOL pedestrian;
@property (nonatomic) BOOL bicycle;
@property (nonatomic) BOOL motorcycle;
@property (nonatomic) BOOL other;
@property (nonatomic) BOOL escooter;
@property (nonatomic) NSInteger incidentId;

@end

@interface TripMotion : NSObject
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@property (nonatomic) NSTimeInterval timestamp;
@end

@interface TripGyro : NSObject
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@end

@interface TripLocation : NSObject
@property (strong, nonatomic) CLLocation *location;
@property (strong, nonatomic) TripGyro *gyro;
@property (strong, nonatomic) NSMutableArray <TripMotion *> *tripMotions;
@property (strong, nonatomic, nullable) TripAnnotation *tripAnnotation;
@end

@interface TripInfo : NSObject
@property (nonatomic) NSInteger identifier;
@property (nonatomic) NSInteger version;
@property (nonatomic) Boolean edited;
@property (nonatomic) Boolean uploaded;
@property (nonatomic) NSURL *csvFile;
@property (strong, nonatomic) NSString *fileHash;
@property (strong, nonatomic) NSString *filePasswd;
@property (nonatomic) NSDateInterval *duration;
@property (nonatomic) NSInteger length;

- (instancetype)initFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)asDictionary;
@end

@interface Trip : UploaderObject <CLLocationManagerDelegate>
@property (nonatomic, readonly) NSInteger identifier;
@property (strong, nonatomic, readonly) CLLocation *startLocation;
@property (strong, nonatomic, readonly) CLLocation *lastLocation;
@property (strong, nonatomic, readonly) TripMotion *lastTripMotion;
@property (strong, nonatomic) NSMutableArray <TripLocation *> *tripLocations;
@property (nonatomic, readonly) NSInteger deferredSecs;
@property (nonatomic, readonly) NSInteger deferredMeters;
@property (nonatomic) NSInteger bikeTypeId;
@property (nonatomic) NSInteger positionId;
@property (nonatomic) Boolean childseat;
@property (nonatomic) Boolean trailer;

- (instancetype)initFromDefaults:(NSInteger)identifier;
- (instancetype)initFromDictionary:(NSDictionary *)dict;
- (void)startRecording;
- (void)stopRecording;
- (NSInteger)tripMotions;
- (NSInteger)tripAnnotations;
- (NSInteger)numberOfScary;
- (NSDateInterval *)duration;
- (NSInteger)length;
- (NSInteger)idle;
- (NSDictionary *)asDictionary;
- (TripInfo *)tripInfo;
@end

NS_ASSUME_NONNULL_END
