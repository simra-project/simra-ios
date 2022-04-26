//
//  ProfileTVC.m
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "ProfileTVC.h"
#import "IdPicker.h"
#import "AppDelegate.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"

@interface ProfileTVC()

@property (weak, nonatomic) IBOutlet IdPicker *age;
@property (weak, nonatomic) IBOutlet IdPicker *sex;
@property (weak, nonatomic) IBOutlet IdPicker *region;
@property (weak, nonatomic) IBOutlet IdPicker *experience;
@property (weak, nonatomic) IBOutlet UISwitch *behaviourSwitch;
@property (weak, nonatomic) IBOutlet UISlider *behaviourSlider;
@property (weak, nonatomic) IBOutlet UILabel *totalRides;
@property (weak, nonatomic) IBOutlet UILabel *totalLength;
@property (weak, nonatomic) IBOutlet UILabel *averageDistance;
@property (weak, nonatomic) IBOutlet UILabel *totalCO2;
@property (weak, nonatomic) IBOutlet UILabel *totalDuration;
@property (weak, nonatomic) IBOutlet UILabel *totalIdle;
@property (weak, nonatomic) IBOutlet UILabel *averageIdle;
@property (weak, nonatomic) IBOutlet UILabel *averageSpeed;
@property (weak, nonatomic) IBOutlet UILabel *totalIncidents;
@property (weak, nonatomic) IBOutlet UILabel *scaryEvents;
@property (weak, nonatomic) IBOutlet UIView *totalSlots;

@property (strong, nonatomic) UIAlertController *ac;

@end

@implementation ProfileTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = [AppDelegate sharedDelegate];
    self.age.array = [ad.constants valueForKey:@"ages"];
    self.sex.array = [ad.constants valueForKey:@"sexes"];
    self.region.array = [ad.regions regionTextsSorted];
    self.experience.array = [ad.constants valueForKey:@"experiences"];

    [self update];
}
-(void)viewWillDisappear:(BOOL)animated{
    [self writeToProfilePlist];
}
- (void)update {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    
    self.age.arrayIndex = [ad.defaults integerForKey:@"ageId"];
    self.sex.arrayIndex = [ad.defaults integerForKey:@"sexId"];
    self.region.arrayIndex = ad.regions.indexForRegionId;
    if (!ad.regions.regionSelected ||
        [ad.regions.currentRegion.identifier isEqualToString:@"other"] ||
        !ad.regions.selectedIsOneOfThe3ClosestsRegions) {
        self.region.textColor = [UIColor redColor];
    } else {
        if (@available(iOS 13.0, *)) {
            self.region.textColor = [UIColor labelColor];
        } else {
            self.region.textColor = [UIColor darkTextColor];
        }
    }
    self.experience.arrayIndex = [ad.defaults integerForKey:@"experienceId"];
    self.behaviourSwitch.on = [ad.defaults boolForKey:@"behaviour"];
    self.behaviourSlider.enabled = self.behaviourSwitch.on;
    self.behaviourSlider.value = [ad.defaults integerForKey:@"behaviourValue"];
    
    self.totalIdle.text = hms([ad.defaults doubleForKey:@"totalIdle"] / 1000.0);
    self.averageIdle.text = hms([ad.defaults doubleForKey:@"totalIdle"] / 1000.0 / [ad.defaults stringForKey:@"totalRides"].integerValue);
    self.scaryEvents.text = [ad.defaults stringForKey:@"numberOfScary"];
    self.totalRides.text = [ad.defaults stringForKey:@"totalRides"];
    self.totalLength.text = [NSString stringWithFormat:@"%.1f km",
                             [ad.defaults doubleForKey:@"totalLength"] / 1000.0];
    self.averageDistance.text = [NSString stringWithFormat:@"%.1f km",
                                 [ad.defaults doubleForKey:@"totalLength"] / 1000.0 / [ad.defaults stringForKey:@"totalRides"].integerValue];
    self.totalCO2.text = [NSString stringWithFormat:@"%.1f kg",
                          ([ad.defaults doubleForKey:@"totalLength"] / 1000.0 * 0.138)];
    self.totalDuration.text = hms([ad.defaults doubleForKey:@"totalDuration"] / 1000.0);
    self.averageSpeed.text = [NSString stringWithFormat:@"%.1f km/h",
                              (
                               ([ad.defaults doubleForKey:@"totalLength"] / 1000.0) /
                               (
                                (
                                 ([ad.defaults doubleForKey:@"totalDuration"] / 1000.0) -
                                 ([ad.defaults doubleForKey:@"totalIdle"] / 1000.0)
                                 ) /
                                3600.0
                                )
                               )
                              ];
    self.totalIncidents.text = [ad.defaults stringForKey:@"totalIncidents"];
    
    NSArray *totalSlots = [ad.defaults arrayForKey:@"totalSlots"];
    NSArray *totalRefs = @[@"00",@"",@"",
                           @"03",@"",@"",
                           @"06",@"",@"",
                           @"09",@"",@"",
                           @"12", @"",@"",
                           @"15",@"",@"",
                           @"18",@"",@"",
                           @"21",@"",@"23"];
    
    DSBarChart *chrt = [[DSBarChart alloc] initWithFrame:self.totalSlots.bounds
                                                   color:[UIColor blackColor]
                                              references:totalRefs
                                               andValues:totalSlots];
    chrt.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    chrt.bounds = self.totalSlots.bounds;
    [self.totalSlots addSubview:chrt];
}
-(void)writeToProfilePlist{
    [Utility writeProfile];
}

- (IBAction)closestPressed:(UIButton *)sender {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Closest Regions to your Location",
                                                          @"Closest Regions to your Location")
               message:nil
               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *aac = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                          @"Cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * _Nonnull action) {
        //
    }];
    [self.ac addAction:aac];
    
    AppDelegate *ad = [AppDelegate sharedDelegate];
    for (NSInteger n=0; n<MIN(ad.regions.closestsRegions.count, 3); ++n) {
        UIAlertAction *aa = [UIAlertAction actionWithTitle:[ad.regions.closestsRegions[n] localizedDescription]
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [ad.regions selectPosition:ad.regions.closestsRegions[n].position];
            [self update];
        }];
        [self.ac addAction:aa];
    }
    
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

- (IBAction)ageChanged:(IdPicker *)sender {
    [Utility saveIntWithKey:@"ageId" value:sender.arrayIndex];
}

- (IBAction)sexChanged:(IdPicker *)sender {
    [Utility saveIntWithKey:@"sexId" value:sender.arrayIndex];
}

- (IBAction)regionChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.regions selectIdSorted:sender.arrayIndex];
    [self update];
}

- (IBAction)experienceChanged:(IdPicker *)sender {
    [Utility saveIntWithKey:@"experienceId" value:sender.arrayIndex];
}

- (IBAction)behaviourSwitchChanged:(UISwitch *)sender {
    [Utility saveBoolWithKey:@"behaviour" value:sender.on];
    [self update];
}

- (IBAction)behaviourSliderChanged:(UISlider *)sender {
    [Utility saveIntWithKey:@"behaviourValue" value:round(sender.value)];
    [self update];
}

@end
