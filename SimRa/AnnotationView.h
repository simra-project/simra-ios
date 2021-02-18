//
//  AnnotationView.h
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AnnotationView : MKAnnotationView
@property (strong, nonatomic) UIImage *personImage;
@property (nonatomic) BOOL recording;
@property (nonatomic) double speed;
@property (nonatomic) double course;
@property (nonatomic) double accx;
@property (nonatomic) double accy;
@property (nonatomic) double accz;
@property (nonatomic) double heading;

- (UIImage *)getImage;

@end

NS_ASSUME_NONNULL_END
