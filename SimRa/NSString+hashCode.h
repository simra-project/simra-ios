//
//  NSString+hashCode.h
//  SimRa
//
//  Created by Christoph Krey on 03.04.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (hashCode)
- (UInt32)hashCode;
- (NSString *)hashString;
+ (NSString *)clientHash;

@end

NS_ASSUME_NONNULL_END
