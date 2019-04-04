//
//  TripEditVC.h
//  SimRa
//
//  Created by Christoph Krey on 29.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "Trip.h"

NS_ASSUME_NONNULL_BEGIN

@interface TripEditVC : UIViewController <MKMapViewDelegate>
@property (weak, nonatomic) Trip *trip;
@property (nonatomic) BOOL changed;

@end

NS_ASSUME_NONNULL_END
