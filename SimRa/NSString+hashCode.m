//
//  NSString+hashCode.m
//  SimRa
//
//  Created by Christoph Krey on 03.04.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "NSString+hashCode.h"
#import "Hash-Suffix.h"

@implementation NSString (hashCode)
- (UInt32)hashCode {
    // Java String hashCode() method
    // The hash code for a String object is computed as:
    // s[0]*31^(n-1) + s[1]*31^(n-2) + … + s[n-1]
    // where :
    // s[i] – is the ith character of the string
    // n – is the length of the string, and
    // ^ – indicates exponentiation

    // client = @"02.04.2019mcc_simra"; // should result in 0xeaa555f0

    UInt32 hashCode = 0;
    if (self.length > 0) {
        hashCode = [self characterAtIndex:0];
    }
    for (NSInteger i = 1; i < self.length; i++) {
        hashCode *= 31;
        hashCode += [self characterAtIndex:i];
    }
    return hashCode;
}

- (NSString *)hashString {
    NSString *hashString = [NSString stringWithFormat:@"%08x", self.hashCode];
    return hashString;
}


+ (NSString *)clientHash {
    // Java Code
    // public static final SimpleDateFormat DATE_PATTERN_SHORT = new SimpleDateFormat("dd.MM.yyyy");
    // public static final String UPLOAD_HASH_SUFFIX = "mcc_simra";

    // Date dateToday = new Date();
    // String clientHash = Integer.toHexString((DATE_PATTERN_SHORT.format(dateToday) + UPLOAD_HASH_SUFFIX).hashCode());

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"dd.MM.yyyy";
    NSString *client = [NSString stringWithFormat:@"%@%@",
                        [df stringFromDate:[NSDate date]],
                        HASH_SUFFIX];

    return client.hashString;
}

@end
