//
//  SettingsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "SettingsTVC.h"
#import <MessageUI/MessageUI.h>
#import "IdPicker.h"
#import "AppDelegate.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"

@interface SettingsTVC ()

@property (weak, nonatomic) IBOutlet UILabel *version;

@property (strong, nonatomic) UIAlertController *ac;

@end


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


@implementation SettingsTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self update];
}

- (void)update {
    self.version.text = [NSString stringWithFormat:@"%@-%@-%@",
                         [NSBundle mainBundle].infoDictionary[@"CFBundleName"],
                         [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                         [NSLocale currentLocale].languageCode
                         ];
}

- (IBAction)aboutPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/parameter/en/",
        @"de" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/parameter/de/"
    }];
}

- (IBAction)privacyPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.mcc.tu-berlin.de/menue/research/projects/simra/privacy_policy_statement/parameter/en",
        @"de" : @"https://www.mcc.tu-berlin.de/menue/forschung/projekte/simra/datenschutzerklaerung/parameter/de/"
    }];
}

- (IBAction)howtoPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] showHowTo];
}

- (IBAction)feedbackPressed:(UIButton *)sender {
    if (MFMailComposeViewController.canSendMail) {
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        controller.mailComposeDelegate = self;
        [controller setToRecipients:@[@"ask@mcc.tu-berlin.de"]];
        [controller setSubject:NSLocalizedString(@"Feedback SimRa", @"Feedback SimRa")];
        [controller setMessageBody:NSLocalizedString(@"Dear SimRa Team", @"Dear SimRa Team")
                            isHTML:NO];
        [self presentViewController:controller animated:TRUE completion:nil];
    } else {
        self.ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"SimRa", @"SimRa")
                                                      message:NSLocalizedString(@"Configure your Email, please!", @"Configure your Email, please!")
                                               preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aad = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
        [self.ac addAction:aad];
        [self presentViewController:self.ac animated:TRUE completion:nil];
        return;

    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    if (result == MFMailComposeResultSent) {
        NSLog(@"sent");
    }
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (IBAction)imprintPressed:(UIButton *)sender {
    [[AppDelegate sharedDelegate] openURL:@{
        @"en" : @"https://www.tu-berlin.de/servicemenue/impressum/parameter/en/mobil/",
        @"de" : @"https://www.tu-berlin.de/servicemenue/impressum/parameter/mobil/"
    }];
}

@end

@implementation ProfileTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = [AppDelegate sharedDelegate];

    self.age.array = [ad.constants valueForKey:@"ages"];
    self.sex.array = [ad.constants valueForKey:@"sexes"];
    self.region.array = [ad.regions regionTexts];
    self.experience.array = [ad.constants valueForKey:@"experiences"];

    [self update];
}

- (void)update {
    AppDelegate *ad = [AppDelegate sharedDelegate];

    self.age.arrayIndex = [ad.defaults integerForKey:@"ageId"];
    self.sex.arrayIndex = [ad.defaults integerForKey:@"sexId"];
    self.region.arrayIndex = ad.regions.filteredRegionId;
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
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.arrayIndex forKey:@"ageId"];
}

- (IBAction)sexChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.arrayIndex forKey:@"sexId"];
}

- (IBAction)regionChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.regions selectId:sender.arrayIndex];
    [self update];
}

- (IBAction)experienceChanged:(IdPicker *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:sender.arrayIndex forKey:@"experienceId"];
}

- (IBAction)behaviourSwitchChanged:(UISwitch *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setBool:sender.on forKey:@"behaviour"];
    [self update];
}

- (IBAction)behaviourSliderChanged:(UISlider *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.defaults setInteger:round(sender.value) forKey:@"behaviourValue"];
    [self update];
}

@end

@implementation TripSettingsTVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = [AppDelegate sharedDelegate];

    self.bikeType.array = [ad.constants valueForKey:@"bikeTypes"];
    self.position.array = [ad.constants valueForKey:@"positions"];

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
