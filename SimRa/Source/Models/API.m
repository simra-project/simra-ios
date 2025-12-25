//
//  API.m
//  SimRa
//
//  Created by Christoph Krey on 26.04.22.
//  Copyright © 2022 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "API.h"

#define API_SCHEME @"https:"
#ifdef DEBUG
#define API_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define API_HOST @"simra-backend.3s-rg.de:8082"
#endif
#define API_VERSION 13

@implementation API
+ (NSString *)APIPrefix {
    NSString *prefix = [NSString stringWithFormat:@"%@//%@/%d",
                        API_SCHEME, API_HOST, API_VERSION];
    NSLog(@"APIprefix: %@", prefix);
    return prefix;
}

+ (NSString *)APIShortPrefix {
    NSString *prefix = [NSString stringWithFormat:@"%@//%@",
                        API_SCHEME, API_HOST];
    NSLog(@"APIprefix: %@", prefix);
    return prefix;
}

@end
