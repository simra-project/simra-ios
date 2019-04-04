//
//  TripEditVC.m
//  SimRa
//
//  Created by Christoph Krey on 29.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "TripEditVC.h"
#import "AnnotationTVC.h"

@interface TripPoint : NSObject <MKAnnotation>
@property (nonatomic, copy) NSString *title;
@property (weak, nonatomic) TripLocation *tripLocation;
@property (weak, nonatomic) NSArray <TripLocation *> *tripLocations;
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

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate {
    CLLocation *location = [[CLLocation alloc] initWithLatitude:newCoordinate.latitude
                                                      longitude:newCoordinate.longitude];

    TripLocation *closestTripLocation = self.tripLocations.firstObject;
    CLLocationDistance closestDistance = [closestTripLocation.location distanceFromLocation:location];
    for (TripLocation *tripLocation in self.tripLocations) {
        if ([tripLocation.location distanceFromLocation:location] < closestDistance) {
            closestDistance = [tripLocation.location distanceFromLocation:location];
            closestTripLocation = tripLocation;
        }
    }
    self.tripLocation = closestTripLocation;
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

@end

@implementation TripEditVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.mapView.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setup];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.changed) {
        self.trip.edited = TRUE;
        [self.trip save];
    }
    [super viewWillDisappear:animated];
}

- (void)setup {
    [self.mapView removeOverlays:self.mapView.overlays];
    [self.mapView removeAnnotations:self.mapView.annotations];

    if (self.trip.tripLocations.count > 0) {
        self.tripTrack = [[TripTrack alloc] init];
        self.tripTrack.trip = self.trip;
        [self.mapView addOverlay:self.tripTrack];

        [self.mapView setVisibleMapRect:self.tripTrack.boundingMapRect
                            edgePadding:UIEdgeInsetsMake(50.0, 50.0, 50.0, 50.0)
                               animated:TRUE];

        self.startPoint = [[TripPoint alloc] init];
        self.startPoint.title = NSLocalizedString(@"Start", @"Start");
        self.startPoint.tripLocation = self.trip.tripLocations.firstObject;
        self.startPoint.tripLocations = self.trip.tripLocations;
        [self.mapView addAnnotation:self.startPoint];

        self.endPoint = [[TripPoint alloc] init];
        self.endPoint.title = NSLocalizedString(@"Finish", @"Finish");
        self.endPoint.tripLocation = self.trip.tripLocations.lastObject;
        self.endPoint.tripLocations = self.trip.tripLocations;
        [self.mapView addAnnotation:self.endPoint];

        self.tripPoints = [[NSMutableArray alloc] init];
        for (TripLocation *tripLocation in self.trip.tripLocations) {
            if (tripLocation.tripAnnotation) {
                TripPoint *tripPoint = [[TripPoint alloc] init];
                tripPoint.title = NSLocalizedString(@"Automatic", @"Automatic");
                tripPoint.tripLocation = tripLocation;
                tripPoint.tripLocations = self.trip.tripLocations;

                [self.tripPoints addObject:tripPoint];
                [self.mapView addAnnotation:tripPoint];
            }
        }
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if (annotation == self.startPoint) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"startPoint"];
        MKPinAnnotationView *pinAnnotationView;
        if (annotationView) {
            pinAnnotationView = (MKPinAnnotationView *)annotationView;
        } else {
            pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:self.startPoint
                                                                reuseIdentifier:@"startPoint"];
        }
        pinAnnotationView.pinTintColor = MKPinAnnotationView.greenPinColor;
        pinAnnotationView.draggable = true;
        pinAnnotationView.canShowCallout = YES;
        [pinAnnotationView setNeedsDisplay];

        return pinAnnotationView;

    } else if (annotation == self.endPoint) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"endPoint"];
        MKPinAnnotationView *pinAnnotationView;
        if (annotationView) {
            pinAnnotationView = (MKPinAnnotationView *)annotationView;
        } else {
            pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:self.endPoint
                                                                reuseIdentifier:@"endPoint"];
        }
        pinAnnotationView.pinTintColor = MKPinAnnotationView.redPinColor;
        pinAnnotationView.draggable = true;
        pinAnnotationView.canShowCallout = YES;
        [pinAnnotationView setNeedsDisplay];

        return pinAnnotationView;

    } else if ([self.tripPoints containsObject:annotation]) {
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"tripPoint"];
        MKPinAnnotationView *pinAnnotationView;
        if (annotationView) {
            pinAnnotationView = (MKPinAnnotationView *)annotationView;
        } else {
            pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:self.endPoint
                                                                reuseIdentifier:@"tripPoint"];
        }
        pinAnnotationView.pinTintColor = [UIColor blueColor];

        UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [refreshButton setTitle:NSLocalizedString(@"Delete", @"Delete") forState:UIControlStateNormal];
        [refreshButton sizeToFit];
        pinAnnotationView.leftCalloutAccessoryView = refreshButton;
        pinAnnotationView.canShowCallout = YES;
        pinAnnotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];

        [pinAnnotationView setNeedsDisplay];

        return pinAnnotationView;

    } else {
        return nil;
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
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
    if (sender.state == UIGestureRecognizerStateBegan) {
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
        tripPoint.title = NSLocalizedString(@"Manual", @"Manual");
        tripPoint.tripLocation = closestTripLocation;
        tripPoint.tripLocations = self.trip.tripLocations;

        [self.tripPoints addObject:tripPoint];
        [self.mapView addAnnotation:tripPoint];
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
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

- (IBAction)annotationChanged:(UIStoryboardSegue *)unwindSegue {
    self.changed = TRUE;
}
@end
