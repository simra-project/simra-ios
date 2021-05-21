//
//  TripsSettingsTVC.m
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "TripsSettingsTVC.h"
#import "IdPicker.h"
#import "AppDelegate.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"

@interface TripSettingsTVC()

@property (weak, nonatomic) IBOutlet UISlider *startSecs;
@property (weak, nonatomic) IBOutlet UISlider *startMeters;
@property (weak, nonatomic) IBOutlet UILabel *startSecsLabel;
@property (weak, nonatomic) IBOutlet UILabel *startMetersLabel;
@property (weak, nonatomic) IBOutlet IdPicker *bikeType;
@property (weak, nonatomic) IBOutlet IdPicker *position;
@property (weak, nonatomic) IBOutlet UISwitch *childSeat;
@property (weak, nonatomic) IBOutlet UISwitch *trailer;
@property (weak, nonatomic) IBOutlet UISwitch *AI;

@end


@implementation TripSettingsTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = [AppDelegate sharedDelegate];
    
    self.bikeType.array = [ad.constants mutableArrayValueForKey:@"bikeTypes"];
    self.position.array = [ad.constants mutableArrayValueForKey:@"positions"];
    
    [self update];
}

- (void)update {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    
    self.bikeType.arrayIndex = [ad.defaults integerForKey:@"bikeTypeId"];
    self.position.arrayIndex = [ad.defaults integerForKey:@"positionId"];
    
    self.startSecs.value = [ad.defaults integerForKey:@"deferredSecs"];
    self.startSecsLabel.text = [ad.defaults stringForKey:@"deferredSecs"];
    self.startMeters.value = [ad.defaults integerForKey:@"deferredMeters"];
    self.startMetersLabel.text = [ad.defaults stringForKey:@"deferredMeters"];
    self.childSeat.on = [ad.defaults boolForKey:@"childSeat"];
    self.trailer.on = [ad.defaults boolForKey:@"trailer"];
    self.AI.on = [ad.defaults boolForKey:@"AI"];
}

- (IBAction)deferredSecsChanged:(UISlider *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.value forKey:@"deferredSecs"];
    [self update];
}

- (IBAction)deferredMetersChanged:(UISlider *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.value forKey:@"deferredMeters"];
    [self update];
}

- (IBAction)bikeTypeChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.arrayIndex forKey:@"bikeTypeId"];
}

- (IBAction)positionChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.arrayIndex forKey:@"positionId"];
}

- (IBAction)childSeatChanged:(UISwitch *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setBool:sender.on forKey:@"childSeat"];
}

- (IBAction)trailerChanged:(UISwitch *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setBool:sender.on forKey:@"trailer"];
}

- (IBAction)AIChanged:(UISwitch *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setBool:sender.on forKey:@"AI"];
}

@end
