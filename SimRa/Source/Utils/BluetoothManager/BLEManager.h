//
//  BLEManager.h
//  SimRa
//
//  Created by Hamza Khan on 15/07/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLEManager : NSObject{
    NSString *someProperty;
}

@property (nonatomic, retain) NSString *someProperty;



+ (id)sharedManager;


@end

NS_ASSUME_NONNULL_END
