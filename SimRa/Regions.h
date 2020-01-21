//
//  Regions.h
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Region.h"

NS_ASSUME_NONNULL_BEGIN

@interface Regions : NSObject
@property (nonatomic, readonly) NSInteger regionId;

- (BOOL)regionSelected;
- (NSArray <NSString *> *)regionTexts;
- (NSInteger)regionId;
- (NSInteger)filteredRegionId;
- (void)selectId:(NSInteger)Id;
- (Region *)currentRegion;

@end

NS_ASSUME_NONNULL_END
