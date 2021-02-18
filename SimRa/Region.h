//
//  Region.h
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//  Copyright © 2020-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Region : NSObject
@property (strong, nonatomic) NSString *identifier;
@property (strong, nonatomic) NSString *englishDescription;
@property (strong, nonatomic) NSString *germanDescription;

- (NSString *)localizedDescription;
@end

NS_ASSUME_NONNULL_END
