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
