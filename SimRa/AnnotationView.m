//
//  AnnotationView.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "AnnotationView.h"

@implementation AnnotationView

#define CIRCLE_SIZE 100.0
#define CIRCLE_COLOR [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.5]

#define FENCE_COLOR [UIColor colorWithRed:77.0 / 255.0 green:97.0 / 255.0 blue:137.0 / 255.0 alpha:1.0]
#define FENCE_WIDTH 3.0

#define COURSE_COLOR [UIColor blueColor]
#define COURSE_WIDTH 10.0

#define ACCX_COLOR [UIColor colorWithRed:0.0 green:1.0 blue:0 alpha:0.5]
#define ACCX_WIDTH 2.0

#define ACCY_COLOR [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.5]
#define ACCY_WIDTH 2.0

#define ACCZ_COLOR [UIColor colorWithRed:0.0 green:0 blue:1.0 alpha:0.5]
#define ACCZ_WIDTH 2.0

#define TACHO_COLOR [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.5]
#define TACHO_MAX 50.0 // km/h

#define CONTROL_FILL_COLOR [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.75]
#define CONTROL_STROKE_COLOR [UIColor whiteColor]


/** This method does not seem to be called anymore in ios10
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self internalInit];
    return self;
}

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    [self internalInit];
    return self;
}

- (void)internalInit {
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.frame = CGRectMake(0, 0, CIRCLE_SIZE, CIRCLE_SIZE);
}

- (void)setPersonImage:(UIImage *)image {
    if (image) {
        _personImage = [UIImage imageWithCGImage:image.CGImage
                                           scale:(MAX(image.size.width, image.size.height) / CIRCLE_SIZE)
                                     orientation:UIImageOrientationUp];
    } else {
        _personImage = nil;
    }
}

- (UIImage *)getImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(CIRCLE_SIZE, CIRCLE_SIZE), NO, 0.0);
    [self drawRect:CGRectMake(0, 0, CIRCLE_SIZE, CIRCLE_SIZE)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)drawRect:(CGRect)rect {
    // It is all within a circle
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];
    [circle addClip];

    // Yellow or Photo background
    [CIRCLE_COLOR setFill];
    [circle fill];

    if (self.personImage != nil) {
        [self.personImage drawInRect:rect];
    }

    // Tachometer
    if (self.speed > 0) {
        UIBezierPath *tacho = [[UIBezierPath alloc] init];
        [tacho moveToPoint:CGPointMake(rect.origin.x + rect.size.width / 2.0,
                                       rect.origin.y + rect.size.height / 2.0)];
        [tacho appendPath:[UIBezierPath
                           bezierPathWithArcCenter: CGPointMake(rect.size.width / 2.0,
                                                                rect.size.height / 2.0)
                           radius:CIRCLE_SIZE / 2.0
                           startAngle:M_PI_2 + M_PI / 6.0
                           endAngle:M_PI_2 + M_PI / 6.0 + M_PI * 2.0 * 5.0 / 6.0 * (MIN(self.speed * 3.6 / TACHO_MAX, 1.0))
                           clockwise:true]];
        [tacho addLineToPoint:CGPointMake(rect.origin.x + rect.size.width / 2.0,
                                          rect.origin.y + rect.size.height / 2.0)];
        [tacho closePath];

        [TACHO_COLOR setFill];
        [tacho fill];
        [CIRCLE_COLOR setStroke];
        tacho.lineWidth = 1.0;
        [tacho stroke];
    }

    // FENCE
    [circle setLineWidth:FENCE_WIDTH];
    [FENCE_COLOR setStroke];
    [circle stroke];

    // Course
    if (self.course > 0) {
        UIBezierPath *course = [UIBezierPath bezierPathWithOvalInRect:
                                CGRectMake(
                                           rect.origin.x + rect.size.width / 2 + CIRCLE_SIZE / 2 * cos((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                           rect.origin.y + rect.size.height / 2 + CIRCLE_SIZE / 2 * sin((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                           COURSE_WIDTH,
                                           COURSE_WIDTH
                                           )
                                ];
        [COURSE_COLOR setFill];
        [course fill];
        [CIRCLE_COLOR setStroke];
        course.lineWidth = 1.0;
        [course stroke];
    }

    // Accelleration
    if (self.accx != 0 || self.accy != 0 ||self.accz != 0) {
        UIBezierPath *accx = [UIBezierPath bezierPathWithOvalInRect:
                              CGRectMake(
                                         rect.origin.x + rect.size.width / 2,
                                         rect.origin.y + rect.size.height / 2,
                                         fabs(self.accx) * rect.size.width / 2,
                                         fabs(self.accx) * rect.size.height / 2
                                         )
                              ];
        [ACCX_COLOR setFill];
        [accx fill];
        [CIRCLE_COLOR setStroke];
        accx.lineWidth = ACCX_WIDTH;
        [accx stroke];

        UIBezierPath *accy = [UIBezierPath bezierPathWithOvalInRect:
                              CGRectMake(
                                         rect.origin.x + (1 - fabs(self.accy)) * rect.size.width / 2,
                                         rect.origin.y + rect.size.height / 2,
                                         fabs(self.accy) * rect.size.width / 2,
                                         fabs(self.accy) * rect.size.height / 2
                                         )
                              ];
        [ACCY_COLOR setFill];
        [accy fill];
        [CIRCLE_COLOR setStroke];
        accy.lineWidth = ACCY_WIDTH;
        [accy stroke];

        UIBezierPath *accz = [UIBezierPath bezierPathWithOvalInRect:
                              CGRectMake(
                                         rect.origin.x + (1 - fabs(self.accz) / 2) * rect.size.width / 2,
                                         rect.origin.y + (1 - fabs(self.accz)) * rect.size.height / 2,
                                         fabs(self.accz) * rect.size.width / 2,
                                         fabs(self.accz) * rect.size.height / 2
                                         )
                              ];
        [ACCZ_COLOR setFill];
        [accz fill];
        [CIRCLE_COLOR setStroke];
        accz.lineWidth = ACCZ_WIDTH;
        [accz stroke];
    }

    // Record - Stop control
    UIBezierPath *control;

    if (self.recording) {
        control = [UIBezierPath bezierPathWithRoundedRect:
                   CGRectMake(
                              rect.origin.x + rect.size.width / 4,
                              rect.origin.y + rect.size.height / 4,
                              rect.size.width / 2,
                              rect.size.height / 2
                              )
                                             cornerRadius:rect.size.width / 16
                   ];
    } else {
        control = [UIBezierPath bezierPathWithOvalInRect:
                   CGRectMake(
                              rect.origin.x + rect.size.width / 8,
                              rect.origin.y + rect.size.height / 8,
                              rect.size.width / 4 * 3,
                              rect.size.height / 4 * 3
                              )
                   ];
    }


    [CONTROL_FILL_COLOR setFill];
    [control fill];
    [CONTROL_STROKE_COLOR setStroke];
    control.lineWidth = 1.0;
    [control stroke];
}

@end
