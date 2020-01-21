//
//  AppDelegate.h
//  simra
//
//  Created by Christoph Krey on 27.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import "Trips.h"
#import "Regions.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) NSUserDefaults *defaults;
@property (strong, nonatomic) CLLocationManager *lm;
@property (strong, nonatomic) CMMotionManager *mm;
@property (strong, nonatomic) Trips *trips;
@property (strong, nonatomic) NSDictionary *constants;
@property (strong, nonatomic) Regions *regions;

@end

