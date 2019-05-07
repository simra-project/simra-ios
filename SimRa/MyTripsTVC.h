//
//  MyTripsTVC.h
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Trips.h"

NS_ASSUME_NONNULL_BEGIN

@interface MyTripsTVC : UITableViewController
@property (strong, nonatomic, nullable) Trip *preselectedTrip;

@end

NS_ASSUME_NONNULL_END
