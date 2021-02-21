//
//  News.h
//  SimRa
//
//  Created by Christoph Krey on 21.02.21.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface News : NSObject
@property (nonatomic, readonly) NSInteger newsVersion;
@property (nonatomic, readonly) NSMutableArray <NSString *> *newsLines;
- (void)seen;

@end

NS_ASSUME_NONNULL_END
