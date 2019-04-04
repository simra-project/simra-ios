//
//  Trips.h
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Trip.h"
#import "UploaderObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface Trips : UploaderObject
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, Trip *> *trips;

- (Trip *)newTrip;
- (void)deleteTripWithIdentifier:(NSInteger)identifier;
- (void)addTripToStatistics:(Trip *)trip;

@end

NS_ASSUME_NONNULL_END
