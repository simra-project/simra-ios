//
//  TripDetailTVC.h
//  SimRa
//
//  Created by Christoph Krey on 02.05.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Trip.h"

NS_ASSUME_NONNULL_BEGIN

@interface TripDetailTVC : UITableViewController
@property (weak, nonatomic) Trip *trip;

@end

NS_ASSUME_NONNULL_END
