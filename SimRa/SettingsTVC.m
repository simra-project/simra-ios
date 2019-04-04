//
//  SettingsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "SettingsTVC.h"
#import <MessageUI/MessageUI.h>
#import "IdPicker.h"
#import "AppDelegate.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"

@interface SettingsTVC ()
@property (weak, nonatomic) IBOutlet IdPicker *age;
@property (weak, nonatomic) IBOutlet IdPicker *sex;
@property (weak, nonatomic) IBOutlet IdPicker *region;
@property (weak, nonatomic) IBOutlet IdPicker *experience;
@property (weak, nonatomic) IBOutlet IdPicker *position;
@property (weak, nonatomic) IBOutlet IdPicker *bikeType;
@property (weak, nonatomic) IBOutlet UISwitch *childSeat;
@property (weak, nonatomic) IBOutlet UISwitch *trailer;
@property (weak, nonatomic) IBOutlet UISlider *startSecs;
@property (weak, nonatomic) IBOutlet UISlider *startMeters;
@property (weak, nonatomic) IBOutlet UILabel *startSecsLabel;
@property (weak, nonatomic) IBOutlet UILabel *startMetersLabel;

@property (weak, nonatomic) IBOutlet UITextField *totalRides;
@property (weak, nonatomic) IBOutlet UITextField *totalLength;
@property (weak, nonatomic) IBOutlet UITextField *totalDuration;
@property (weak, nonatomic) IBOutlet UITextField *totalIncidents;
@property (weak, nonatomic) IBOutlet UITextField *totalIdle;
@property (weak, nonatomic) IBOutlet UIView *totalSlots;

@property (strong, nonatomic) UIAlertController *ac;

@end

@implementation SettingsTVC

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    self.age.array = [ad.constants mutableArrayValueForKey:@"ages"];
    self.sex.array = [ad.constants mutableArrayValueForKey:@"sexes"];
    self.region.array = [ad.constants mutableArrayValueForKey:@"regions"];
    self.experience.array = [ad.constants mutableArrayValueForKey:@"experiences"];
    self.bikeType.array = [ad.constants mutableArrayValueForKey:@"bikeTypes"];
    self.position.array = [ad.constants mutableArrayValueForKey:@"positions"];

    [self update];
}

- (void)update {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    self.age.arrayIndex = [ad.defaults integerForKey:@"ageId"];
    self.sex.arrayIndex = [ad.defaults integerForKey:@"sexId"];
    self.region.arrayIndex = [ad.defaults integerForKey:@"regionId"];
    self.experience.arrayIndex = [ad.defaults integerForKey:@"experienceId"];

    self.totalIdle.text = hms([ad.defaults doubleForKey:@"totalIdle"] / 1000.0);
    self.totalRides.text = [ad.defaults stringForKey:@"totalRides"];
    self.totalLength.text = [NSString stringWithFormat:@"%.1f km",
                             [ad.defaults doubleForKey:@"totalLength"] / 1000.0];
    self.totalDuration.text = hms([ad.defaults doubleForKey:@"totalDuration"] / 1000.0);
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

    self.bikeType.arrayIndex = [ad.defaults integerForKey:@"bikeTypeId"];
    self.position.arrayIndex = [ad.defaults integerForKey:@"positionId"];

    self.startSecs.value = [ad.defaults integerForKey:@"deferredSecs"];
    self.startSecsLabel.text = [ad.defaults stringForKey:@"deferredSecs"];
    self.startMeters.value = [ad.defaults integerForKey:@"deferredMeters"];
    self.startMetersLabel.text = [ad.defaults stringForKey:@"deferredMeters"];
    self.childSeat.on = [ad.defaults boolForKey:@"childSeat"];
    self.trailer.on = [ad.defaults boolForKey:@"trailer"];
}

- (IBAction)aboutPressed:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:@"https://www.mcc.tu-berlin.de/menue/forschung/projekte/simra/"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

}
- (IBAction)privacyPressed:(UIButton *)sender {

    NSURL *url = [NSURL URLWithString:@"https://www.tu-berlin.de/allgemeine_seiten/datenschutz/"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

}
- (IBAction)howtoPressed:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:@"http://www.redaktion.tu-berlin.de/fileadmin/fg344/simra/SimRa_Anleitung.pdf"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

}
- (IBAction)feedbackPressed:(UIButton *)sender {
    if (MFMailComposeViewController.canSendMail) {
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        controller.mailComposeDelegate = self;
        [controller setToRecipients:@[@"db@mcc.tu-berlin.de"]];
        [controller setSubject:@"Feedback SimRa"];
        [controller setMessageBody:@"Liebes SimRa Team,\n\n\n\n--sent from SimRa iOS app--" isHTML:NO];
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
    NSURL *url = [NSURL URLWithString:@"https://www.mcc.tu-berlin.de/servicemenue/impressum/"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

}

- (IBAction)ageChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"ageId"];
}
- (IBAction)sexChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"sexId"];
}
- (IBAction)regionChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"regionId"];
}
- (IBAction)experienceChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"experienceId"];
}

- (IBAction)deferredSecsChanged:(UISlider *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.value forKey:@"deferredSecs"];
    [self update];
}

- (IBAction)deferredMetersChanged:(UISlider *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.value forKey:@"deferredMeters"];
    [self update];
}

- (IBAction)bikeTypeChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"bikeTypeId"];
}

- (IBAction)positionChanged:(IdPicker *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:sender.arrayIndex forKey:@"positionId"];
}

- (IBAction)childSeatChanged:(UISwitch *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setBool:sender.on forKey:@"childSeat"];
}
- (IBAction)trailerChanged:(UISwitch *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setBool:sender.on forKey:@"trailer"];
}

@end
