//
//  Region.h
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Region : NSObject
@property (nonatomic) NSInteger position;
@property (strong, nonatomic) NSString *identifier;
@property (strong, nonatomic) NSString *englishDescription;
@property (strong, nonatomic) NSString *germanDescription;
@property (strong, nonatomic) NSNumber *lat;
@property (strong, nonatomic) NSNumber *lon;

- (NSString *)localizedDescription;
- (CLLocation *)location;
- (CLLocationDistance)distanceFrom:(CLLocation *)location;

@end

NS_ASSUME_NONNULL_END
