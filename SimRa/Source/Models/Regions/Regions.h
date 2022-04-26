//
//  Regions.h
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Region.h"
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Regions : NSObject
@property (nonatomic, readonly) NSInteger regionId;
@property (nonatomic, readonly) NSInteger regionsId;
@property (nonatomic, readonly) NSInteger lastSeenRegionsId;
@property (nonatomic, readonly) BOOL loaded;
@property (strong, nonatomic, readonly) NSMutableArray <Region *> *closestsRegions;


- (BOOL)regionSelected;
- (NSArray <NSString *> *)regionTextsSorted;
- (void)computeClosestsRegions:(CLLocation*)location;
- (BOOL)selectedIsOneOfThe3ClosestsRegions;
- (NSInteger)regionId;
- (NSInteger)indexForRegionId;
- (void)selectIdSorted:(NSInteger)Id;
- (void)selectPosition:(NSInteger)position;
- (Region *)currentRegion;
- (void)seen;

@end

NS_ASSUME_NONNULL_END
