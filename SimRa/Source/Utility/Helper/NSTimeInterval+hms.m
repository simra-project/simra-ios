//
//  NSTimeInterval+hms.m
//  SimRa
//
//  Created by Christoph Krey on 03.04.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "NSTimeInterval+hms.h"

NSString *hms(NSTimeInterval timeInterval) {
    NSString *hms = [NSString stringWithFormat:@"%@%02.0f:%02.0f:%02.0f",
                     timeInterval < 0 ? @"-" : @"",
                     floor(fabs(timeInterval) / 3600.0),
                     floor(fmod(fabs(timeInterval) / 60.0, 60.0)),
                     floor(fmod(fabs(timeInterval), 60.0))];
    return hms;
}
