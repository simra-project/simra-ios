//
//  Region.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Region.h"

@implementation Region

- (NSString *)localizedDescription {
    if ([[NSLocale currentLocale].languageCode isEqualToString:@"de"]) {
        if (self.germanDescription) {
            return self.germanDescription;
        } else {
            return self.identifier;
        }
    } else {
        if (self.englishDescription) {
            return self.englishDescription;
        } else {
            return self.identifier;
        }
    }
}

@end
