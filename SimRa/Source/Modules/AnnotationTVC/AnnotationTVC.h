//
//  AnnotationTVC.h
//  SimRa
//
//  Created by Christoph Krey on 29.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Trip.h"

NS_ASSUME_NONNULL_BEGIN

@interface AnnotationTVC : UITableViewController <UITextViewDelegate>
@property (weak, nonatomic) TripAnnotation *tripAnnotation;
@property (nonatomic) BOOL changed;
//@property (weak, nonatomic) NSDictionary *closePassInfo;
//@property (nonatomic) BOOL isClosePassAdded;

@end

NS_ASSUME_NONNULL_END
