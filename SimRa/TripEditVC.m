//
//  TripEditVC.m
//  SimRa
//
//  Created by Christoph Krey on 29.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "TripEditVC.h"
#import "AnnotationTVC.h"
#import "TripDetailTVC.h"
#import "AppDelegate.h"
#import "TTRangeSlider.h"

#define IMAGE_ANNOTATION_VIEW_SIZE 48.0

@interface ImageAnnotationView : MKAnnotationView
@property (strong, nonatomic) UIImage *annotationImage;
- (UIImage *)getImage;

@end

@implementation ImageAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.frame = CGRectMake(0, 0, IMAGE_ANNOTATION_VIEW_SIZE, IMAGE_ANNOTATION_VIEW_SIZE);
    self.centerOffset = CGPointMake(0, -(IMAGE_ANNOTATION_VIEW_SIZE / 2));
    return self;
}

- (void)setAnnotationImage:(UIImage *)image {
    if (image) {
        _annotationImage = [UIImage imageWithCGImage:image.CGImage
                                               scale:(MAX(image.size.width, image.size.height) / IMAGE_ANNOTATION_VIEW_SIZE)
                                         orientation:UIImageOrientationUp];
    } else {
        _annotationImage = nil;
    }
}

- (UIImage *)getImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(IMAGE_ANNOTATION_VIEW_SIZE, IMAGE_ANNOTATION_VIEW_SIZE), NO, 0.0);
    [self drawRect:CGRectMake(0, 0, IMAGE_ANNOTATION_VIEW_SIZE, IMAGE_ANNOTATION_VIEW_SIZE)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)drawRect:(CGRect)rect {
    
    if (self.annotationImage != nil) {
        [self.annotationImage drawInRect:rect];
    }
}

@end

@interface TripPoint : NSObject <MKAnnotation>
@property (nonatomic, copy) NSString *title;
@property (strong, nonatomic) TripLocation *tripLocation;
@end

@implementation TripPoint

- (NSString *)subtitle {
    return [NSDateFormatter localizedStringFromDate:self.tripLocation.location.timestamp
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

- (CLLocationCoordinate2D)coordinate {
    return self.tripLocation.location.coordinate;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[TripPoint class]]) {
        TripPoint *tripPoint = (TripPoint *)object;
        return (self.tripLocation.location.timestamp == tripPoint.tripLocation.location.timestamp);
    } else {
        return false;
    }
}

@end

@interface TripTrack : NSObject <MKOverlay>
@property (weak, nonatomic) Trip *trip;
@end

@implementation TripTrack

- (CLLocationCoordinate2D)coordinate {
    NSAssert(self.trip.tripLocations.count > 0, @"No tripLocations");
    
    return self.trip.tripLocations[0].location.coordinate;
}

- (MKMapRect)boundingMapRect {
    NSAssert(self.trip.tripLocations.count > 0, @"No tripLocations");
    
    MKMapPoint point = MKMapPointForCoordinate(self.trip.tripLocations[0].location.coordinate);
    MKMapRect mapRect = MKMapRectMake(
                                      point.x,
                                      point.y,
                                      1.0,
                                      1.0
                                      );
    for (TripLocation *tripLocation in self.trip.tripLocations) {
        MKMapPoint mapPoint = MKMapPointForCoordinate(tripLocation.location.coordinate);
        if (mapPoint.x < mapRect.origin.x) {
            mapRect.size.width += mapRect.origin.x - mapPoint.x;
            mapRect.origin.x = mapPoint.x;
        } else if (mapPoint.x + 3 > mapRect.origin.x + mapRect.size.width) {
            mapRect.size.width = mapPoint.x - mapRect.origin.x;
        }
        if (mapPoint.y < mapRect.origin.y) {
            mapRect.size.height += mapRect.origin.y - mapPoint.y;
            mapRect.origin.y = mapPoint.y;
        } else if (mapPoint.y > mapRect.origin.y + mapRect.size.height) {
            mapRect.size.height = mapPoint.y - mapRect.origin.y;
        }
    }
    return mapRect;
}

- (MKPolyline *)polyLine {
    NSAssert(self.trip.tripLocations.count > 0, @"No tripLocations");
    
    CLLocationCoordinate2D coordinate = self.coordinate;
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:&coordinate count:1];
    
    CLLocationCoordinate2D *coordinates =
    malloc(self.trip.tripLocations.count * sizeof(CLLocationCoordinate2D));
    if (coordinates) {
        int count = 0;
        for (TripLocation *tripLocation in self.trip.tripLocations) {
            coordinates[count++] = tripLocation.location.coordinate;
        }
        polyLine = [MKPolyline polylineWithCoordinates:coordinates count:self.trip.tripLocations.count];
        free(coordinates);
    }
    return polyLine;
}

@end

@interface TripEditVC ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) TripTrack *tripTrack;
@property (strong, nonatomic) TripPoint *startPoint;
@property (strong, nonatomic) TripPoint *endPoint;
@property (strong, nonatomic) NSMutableArray <TripPoint *> *tripPoints;

@property (strong, nonatomic) UIButton *detailButton;
@property (strong, nonatomic) TTRangeSlider *rangeSlider;
@property (nonatomic) float lastSliderMinSelected;
@property (nonatomic) float lastSliderMaxSelected;
@property (nonatomic) BOOL initialTripDetail;

@end

@implementation TripEditVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.mapView.delegate = self;
    
    self.detailButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    self.detailButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.detailButton addTarget:self action:@selector(infoPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.detailButton];
    
    NSLayoutConstraint *a = [NSLayoutConstraint constraintWithItem:self.detailButton
                                                         attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                            toItem:self.mapView
                                                         attribute:NSLayoutAttributeBottom
                                                        multiplier:1
                                                          constant:-20];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.detailButton
                                                         attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                            toItem:self.mapView
                                                         attribute:NSLayoutAttributeTrailing
                                                        multiplier:1
                                                          constant:-20];
    
    [NSLayoutConstraint activateConstraints:@[a, b]];
    
    self.rangeSlider = [[TTRangeSlider alloc] init];
    self.rangeSlider.backgroundColor = [UIColor colorWithRed:0.5
                                                       green:0.5
                                                        blue:0.5
                                                       alpha:0.5];
    self.rangeSlider.translatesAutoresizingMaskIntoConstraints = false;
    [self.rangeSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    //self.rangeSlider.tintColor = [UIColor blueColor];
    self.rangeSlider.lineHeight = 3;
    self.rangeSlider.lineBorderWidth = 1;
    
    self.rangeSlider.step = 1;
    self.rangeSlider.enableStep = TRUE;
    self.rangeSlider.minDistance = 1;

    self.rangeSlider.hideLabels = TRUE;
    
    [self.view addSubview:self.rangeSlider];
    
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.rangeSlider
                                                           attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
                                                              toItem:self.mapView
                                                           attribute:NSLayoutAttributeTopMargin
                                                          multiplier:1
                                                            constant:20];
    NSLayoutConstraint *leading = [NSLayoutConstraint constraintWithItem:self.rangeSlider
                                                               attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.mapView
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1
                                                                constant:20];
    
    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:self.rangeSlider
                                                                attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.mapView
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1
                                                                 constant:-20];
    
    
    [NSLayoutConstraint activateConstraints:@[top, leading, trailing]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.initialTripDetail) {
        self.initialTripDetail = TRUE;
        [self performSegueWithIdentifier:@"tripDetail:" sender:nil];
    }
    [self setup];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.changed) {
        self.trip.edited = TRUE;
        [self.trip save];
    }
    [super viewWillDisappear:animated];
}

- (IBAction)infoPressed:(id)sender {
    [self performSegueWithIdentifier:@"tripDetail:" sender:nil];
}

- (IBAction)sliderChanged:(TTRangeSlider *)rangeSlider {
    NSLog(@"sliderChanged %lu: %f-%f",
          (unsigned long)self.trip.tripLocations.count,
          rangeSlider.selectedMinimum,
          rangeSlider.selectedMaximum);
    if (self.lastSliderMinSelected != rangeSlider.selectedMinimum ||
        self.lastSliderMaxSelected != rangeSlider.selectedMaximum) {
        self.lastSliderMinSelected = rangeSlider.selectedMinimum;
        self.lastSliderMaxSelected = rangeSlider.selectedMaximum;
        if (self.startPoint && rangeSlider.selectedMinimum < self.trip.tripLocations.count) {
            self.startPoint.tripLocation = self.trip.tripLocations[(NSInteger)rangeSlider.selectedMinimum];
            [self.mapView removeAnnotation:self.startPoint];
            [self.mapView addAnnotation:self.startPoint];
        }
        if (self.endPoint && rangeSlider.selectedMaximum < self.trip.tripLocations.count) {
            self.endPoint.tripLocation = self.trip.tripLocations[(NSInteger)rangeSlider.selectedMaximum];
            [self.mapView removeAnnotation:self.endPoint];
            [self.mapView addAnnotation:self.endPoint];
        }
        if (self.rangeSlider.minValue != self.rangeSlider.selectedMinimum ||
            self.rangeSlider.maxValue != self.rangeSlider.selectedMaximum) {
            self.navigationItem.rightBarButtonItem.enabled = TRUE;
        } else {
            self.navigationItem.rightBarButtonItem.enabled = FALSE;
        }
    }
}

- (void)setup {
    if (self.clean) {
        if (self.tripTrack) {
            [self.mapView removeOverlay:self.tripTrack];
            self.tripTrack = nil;
        }
        if (self.startPoint) {
            [self.mapView removeAnnotation:self.startPoint];
            self.startPoint = nil;
        }
        if (self.startPoint) {
            [self.mapView removeAnnotation:self.endPoint];
            self.endPoint = nil;
        }
        if (self.tripPoints) {
            for (TripPoint *tripPoint in self.tripPoints) {
                [self.mapView removeAnnotation:tripPoint];
            }
            self.tripPoints = nil;
        }
        
        self.clean = FALSE;
    }
    if (self.trip.uploaded) {
        self.navigationItem.rightBarButtonItem.enabled = FALSE;
        self.rangeSlider.hidden = TRUE;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = TRUE;
        self.rangeSlider.hidden = FALSE;
    }
    
    self.rangeSlider.minValue = 0;
    self.rangeSlider.maxValue = self.trip.tripLocations.count - 1;
    
    if (self.trip.tripLocations.count > 0) {
        if (!self.tripTrack) {
            self.tripTrack = [[TripTrack alloc] init];
            self.tripTrack.trip = self.trip;
            [self.mapView addOverlay:self.tripTrack];
            
            [self.mapView setVisibleMapRect:self.tripTrack.boundingMapRect
                                edgePadding:UIEdgeInsetsMake(128.0, 48.0, 128.0, 48.0)
                                   animated:TRUE];
        }
        
        if (!self.startPoint) {
            self.startPoint = [[TripPoint alloc] init];
            self.startPoint.title = NSLocalizedString(@"Start", @"Start");
            self.startPoint.tripLocation = self.trip.tripLocations[0];
            [self.mapView addAnnotation:self.startPoint];
            self.rangeSlider.selectedMinimum = [self.trip.tripLocations indexOfObject:self.startPoint.tripLocation];
        }
        
        if (!self.endPoint) {
            self.endPoint = [[TripPoint alloc] init];
            self.endPoint.title = NSLocalizedString(@"Finish", @"Finish");
            self.endPoint.tripLocation = self.trip.tripLocations[self.trip.tripLocations.count - 1];
            [self.mapView addAnnotation:self.endPoint];
            self.rangeSlider.selectedMaximum = [self.trip.tripLocations indexOfObject:self.endPoint.tripLocation];
        }
        
        if (!self.tripPoints) {
            self.tripPoints = [[NSMutableArray alloc] init];
            AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
            NSArray <NSString *> *incidents = [ad.constants mutableArrayValueForKey:@"incidents"];
            
            for (TripLocation *tripLocation in self.trip.tripLocations) {
                if (tripLocation.tripAnnotation) {
                    TripPoint *tripPoint = [[TripPoint alloc] init];
                    tripPoint.title = incidents[tripLocation.tripAnnotation.incidentId];
                    tripPoint.tripLocation = tripLocation;
                    
                    [self.tripPoints addObject:tripPoint];
                    [self.mapView addAnnotation:tripPoint];
                }
            }
        }
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation {
    if (annotation == self.startPoint) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"startPoint"];
        ImageAnnotationView *imageAnnotationView;
        if (annotationView) {
            imageAnnotationView = (ImageAnnotationView *)annotationView;
        } else {
            imageAnnotationView = [[ImageAnnotationView alloc] initWithAnnotation:annotation
                                                                  reuseIdentifier:@"startPoint"];
        }
        imageAnnotationView.annotationImage = [UIImage imageNamed:@"start"];
        imageAnnotationView.centerOffset = CGPointMake(0, -(IMAGE_ANNOTATION_VIEW_SIZE / 2) + 4);
        imageAnnotationView.canShowCallout = YES;
        [imageAnnotationView setNeedsDisplay];
        
        return imageAnnotationView;
        
    } else if (annotation == self.endPoint) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"endPoint"];
        ImageAnnotationView *imageAnnotationView;
        if (annotationView) {
            imageAnnotationView = (ImageAnnotationView *)annotationView;
        } else {
            imageAnnotationView = [[ImageAnnotationView alloc] initWithAnnotation:annotation
                                                                  reuseIdentifier:@"endPoint"];
        }
        
        imageAnnotationView.annotationImage = [UIImage imageNamed:@"racing-flag"];
        imageAnnotationView.centerOffset = CGPointMake(7, -(IMAGE_ANNOTATION_VIEW_SIZE / 2) + 2);
        
        imageAnnotationView.canShowCallout = YES;
        [imageAnnotationView setNeedsDisplay];
        
        return imageAnnotationView;
        
    } else if ([self.tripPoints containsObject:annotation]) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"tripPoint"];
        MKPinAnnotationView *pinAnnotationView;
        if (annotationView) {
            pinAnnotationView = (MKPinAnnotationView *)annotationView;
        } else {
            pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation
                                                                reuseIdentifier:@"tripPoint"];
        }
        
        TripPoint *tripPoint;
        if ([annotation isKindOfClass:[TripPoint class]]) {
            tripPoint = (TripPoint *)annotation;
            if (tripPoint.tripLocation.tripAnnotation.incidentId == 0) {
                pinAnnotationView.pinTintColor = [UIColor orangeColor];
            } else {
                pinAnnotationView.pinTintColor = [UIColor blueColor];
            }
        } else {
            pinAnnotationView.pinTintColor = MKPinAnnotationView.purplePinColor;;
        }
        
        if (self.trip.uploaded) {
            pinAnnotationView.leftCalloutAccessoryView = nil;
            pinAnnotationView.rightCalloutAccessoryView = nil;
        } else {
            UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [deleteButton setTitle:NSLocalizedString(@"Delete", @"Delete") forState:UIControlStateNormal];
            [deleteButton sizeToFit];
            pinAnnotationView.leftCalloutAccessoryView = deleteButton;
            
            pinAnnotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        }
        
        pinAnnotationView.canShowCallout = YES;
        
        [pinAnnotationView setNeedsDisplay];
        return pinAnnotationView;
        
    } else {
        return nil;
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView
            rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[TripTrack class]]) {
        TripTrack *tripTrack = (TripTrack *)overlay;
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:tripTrack.polyLine];
        renderer.lineWidth = 3;
        renderer.strokeColor = [UIColor redColor];
        return renderer;
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView
 annotationView:(MKAnnotationView *)view
calloutAccessoryControlTapped:(UIControl *)control {
    if (control == view.rightCalloutAccessoryView) {
        [self performSegueWithIdentifier:@"editAnnotation:" sender:view.annotation];
    } else if (control == view.leftCalloutAccessoryView) {
        if ([view.annotation isKindOfClass:[TripPoint class]]) {
            TripPoint *tripPoint = (TripPoint *)view.annotation;
            tripPoint.tripLocation.tripAnnotation = nil;
            NSLog(@"before %@", mapView.annotations);
            [mapView removeAnnotation:tripPoint];
            NSLog(@"after %@", mapView.annotations);
            [self.tripPoints removeObject:tripPoint];
            self.changed = TRUE;
        }
    }
}

- (IBAction)longPressed:(UILongPressGestureRecognizer *)sender {
    if (!self.trip.uploaded) {
        
        if (sender.state == UIGestureRecognizerStateBegan) {
            AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
            NSArray <NSString *> *incidents = [ad.constants mutableArrayValueForKey:@"incidents"];
            
            CGPoint p = [sender locationInView:self.mapView];
            
            CLLocationCoordinate2D coordinate = [self.mapView convertPoint:p toCoordinateFromView:self.mapView];
            CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                              longitude:coordinate.longitude];
            
            TripLocation *closestTripLocation = self.trip.tripLocations.firstObject;
            CLLocationDistance closestDistance = [closestTripLocation.location distanceFromLocation:location];
            for (TripLocation *tripLocation in self.trip.tripLocations) {
                if ([tripLocation.location distanceFromLocation:location] < closestDistance) {
                    closestDistance = [tripLocation.location distanceFromLocation:location];
                    closestTripLocation = tripLocation;
                }
            }
            
            closestTripLocation.tripAnnotation = [[TripAnnotation alloc] init];
            TripPoint *tripPoint = [[TripPoint alloc] init];
            tripPoint.title = incidents[closestTripLocation.tripAnnotation.incidentId];
            tripPoint.tripLocation = closestTripLocation;
            
            [self.tripPoints addObject:tripPoint];
            [self.mapView addAnnotation:tripPoint];
        }
    }
}

- (IBAction)donePressed:(UIBarButtonItem *)sender {    
    for (NSInteger i = 0; i < self.trip.tripLocations.count;) {
        NSInteger startIndex = [self.trip.tripLocations indexOfObject:self.startPoint.tripLocation];
        NSInteger endIndex = [self.trip.tripLocations indexOfObject:self.endPoint.tripLocation];
        if ((i < startIndex && i < endIndex) || (i > startIndex && i > endIndex)) {
            [self.trip.tripLocations removeObjectAtIndex:i];
        } else {
            i++;
        }
    }
    self.changed = TRUE;
    self.clean = TRUE;
    [self setup];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[AnnotationTVC class]] &&
        [sender isKindOfClass:[TripPoint class]]) {
        AnnotationTVC *annotationTVC = (AnnotationTVC *)segue.destinationViewController;
        TripPoint *tripPoint = (TripPoint *)sender;
        annotationTVC.tripAnnotation = tripPoint.tripLocation.tripAnnotation;
        annotationTVC.changed = FALSE;
    }
    if ([segue.destinationViewController isKindOfClass:[TripDetailTVC class]]) {
        TripDetailTVC *tripDetailTVC = (TripDetailTVC *)segue.destinationViewController;
        tripDetailTVC.trip = self.trip;
    }
}

- (IBAction)annotationChanged:(UIStoryboardSegue *)unwindSegue {
    self.changed = TRUE;
    self.clean = TRUE;
    [self setup];
}

@end
