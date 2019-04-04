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
@property (nonatomic) NSInteger incidentId;

@end

@interface TripMotion : NSObject
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@property (nonatomic) NSTimeInterval timestamp;
@end

@interface TripLocation : NSObject
@property (strong, nonatomic) CLLocation *location;
@property (strong, nonatomic) NSMutableArray <TripMotion *> *tripMotions;
@property (strong, nonatomic, nullable) TripAnnotation *tripAnnotation;
@end

@interface Trip : UploaderObject <CLLocationManagerDelegate>
@property (nonatomic, readonly) NSInteger identifier;
@property (strong, nonatomic, readonly) CLLocation *startLocation;
@property (strong, nonatomic, readonly) CLLocation *lastLocation;
@property (strong, nonatomic, readonly) TripMotion *lastTripMotion;
@property (strong, nonatomic) NSMutableArray <TripLocation *> *tripLocations;
@property (nonatomic, readonly) NSInteger deferredSecs;
@property (nonatomic, readonly) NSInteger deferredMeters;
@property (nonatomic, readonly) NSInteger bikeTypeId;
@property (nonatomic, readonly) NSInteger positionId;
@property (nonatomic, readonly) Boolean childseat;
@property (nonatomic, readonly) Boolean trailer;

- (instancetype)initFromDictionary:(NSDictionary *)dict;
- (void)startRecording;
- (void)stopRecording;
- (NSInteger)tripMotions;
- (NSInteger)tripAnnotations;
- (NSDateInterval *)duration;
- (NSInteger)length;
- (NSInteger)idle;
- (NSDictionary *)asDictionary;
@end

NS_ASSUME_NONNULL_END
