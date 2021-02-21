//
//  NewsVC.m
//  SimRa
//
//  Created by Christoph Krey on 21.02.21.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "NewsVC.h"
#import "AppDelegate.h"
#import "News.h"

@interface NewsVC ()
@property (weak, nonatomic) IBOutlet UITextView *newsTextView;

@end

@implementation NewsVC

- (void)viewDidLoad {
    [super viewDidLoad];

    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];

    UIFont *font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    UIColor *colorNormal;
    if (@available(iOS 13.0, *)) {
        colorNormal = [UIColor labelColor];
    } else {
        colorNormal = [UIColor darkTextColor];
    }
    NSDictionary *attributesNormal = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: colorNormal
    };

    UIColor *colorHighlight = [UIColor systemRedColor];
    NSDictionary *attributesHighlight = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: colorHighlight
    };

    for (NSString *line in ad.news.newsLines) {
        if ([line rangeOfString:@"-"].location == 0) {
            [as appendAttributedString:
             [[NSMutableAttributedString alloc] initWithString:[line substringFromIndex:1]
                                                    attributes:attributesNormal]];
            [as appendAttributedString:
             [[NSMutableAttributedString alloc] initWithString:@"\n\n"
                                                    attributes:attributesNormal]];
        } else if ([line rangeOfString:@"*"].location == 0) {
            [as appendAttributedString:
             [[NSMutableAttributedString alloc] initWithString:[line substringFromIndex:1]
                                                    attributes:attributesHighlight]];
            [as appendAttributedString:
             [[NSMutableAttributedString alloc] initWithString:@"\n\n"
                                                    attributes:attributesHighlight]];
        }
    }
    self.newsTextView.attributedText = as;
}

@end
