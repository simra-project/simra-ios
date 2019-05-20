//
//  ViewController.m
//  simra
//
//  Created by Christoph Krey on 27.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Trips.h"
#import "AnnotationView.h"
#import "NSTimeInterval+hms.h"
#import "MyTripsTVC.h"

@interface MyAnnotation: NSObject <MKAnnotation>
@property (strong, nonatomic) CLLocation *location;
- (instancetype)initWithLocation:(CLLocation *)location;
@end

@implementation MyAnnotation
- (CLLocationCoordinate2D)coordinate {
    return self.location.coordinate;
}

- (instancetype)initWithLocation:(CLLocation *)location {
    self = [super init];
    self.location = location;
    return self;
}
@end

@interface ViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *dummyButton;

@property (strong, nonatomic) MKUserTrackingButton *trackingButton;
@property (strong, nonatomic) Trip *trip;
@property (strong, nonatomic) Trip *recordedTrip;

@property (strong, nonatomic) AnnotationView *annotationView;
@property (strong, nonatomic) MyAnnotation *myAnnotation;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.mapView.delegate = self;
    self.mapView.showsScale = TRUE;
    self.mapView.showsCompass = TRUE;
    self.mapView.showsUserLocation = TRUE;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;

    self.trackingButton = [MKUserTrackingButton userTrackingButtonWithMapView:self.mapView];
    self.trackingButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.trackingButton];

    NSLayoutConstraint *a = [NSLayoutConstraint constraintWithItem:self.trackingButton
                                                         attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                            toItem:self.mapView
                                                         attribute:NSLayoutAttributeBottom
                                                        multiplier:1
                                                          constant:-10];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.trackingButton
                                                         attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                            toItem:self.mapView
                                                         attribute:NSLayoutAttributeTrailing
                                                        multiplier:1
                                                          constant:-10];

    [NSLayoutConstraint activateConstraints:@[a, b]];

    self.playButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
    self.navigationItem.leftBarButtonItem.enabled = TRUE;
    self.navigationItem.rightBarButtonItem.enabled = TRUE;

    self.dummyButton.title = NSLocalizedString(@"Not Recording", @"Not Recording");

    // Do any additional setup after loading the view.
}

- (IBAction)playButtonPressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.trip = [ad.trips newTrip];
    [self.trip startRecording];

    self.playButton.enabled = FALSE;
    self.stopButton.enabled = TRUE;
    self.navigationItem.leftBarButtonItem.enabled = FALSE;
    self.navigationItem.rightBarButtonItem.enabled = FALSE;

    [self.trip addObserver:self
                  forKeyPath:@"lastLocation"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
    [self.trip addObserver:self
                  forKeyPath:@"lastTripMotion"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
}

- (IBAction)stopButtonPressed:(UIBarButtonItem *)sender {
    [self.trip removeObserver:self
                     forKeyPath:@"lastLocation"];
    [self.trip removeObserver:self
                     forKeyPath:@"lastTripMotion"];

    [self.trip stopRecording];
    self.recordedTrip = self.trip;
    [self performSegueWithIdentifier:@"trips:" sender:nil];

    self.trip = nil;
    
    self.annotationView.recording = FALSE;
    self.annotationView.speed = 0.0;
    self.annotationView.course = 0.0;
    self.annotationView.accx = 0.0;
    self.annotationView.accy = 0.0;
    self.annotationView.accz = 0.0;
    [self.annotationView setNeedsDisplay];

    self.playButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
    self.navigationItem.leftBarButtonItem.enabled = TRUE;
    self.navigationItem.rightBarButtonItem.enabled = TRUE;
    self.dummyButton.title = NSLocalizedString(@"Not Recording", @"Not Recording");
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
}

- (void)update {
    if (self.annotationView) {
        self.annotationView.recording = self.trip != nil;
        if (self.trip) {
            if (self.trip.lastLocation) {
                //NSLog(@"update lastLocation %@", self.trip.lastLocation);
                self.annotationView.speed = self.trip.lastLocation.speed;
                self.annotationView.course = self.trip.lastLocation.course;
            }
            if (self.trip.lastTripMotion) {
                //NSLog(@"update lastTripMotion %@", self.trip.lastTripMotion);
                self.annotationView.accx = self.trip.lastTripMotion.x;
                self.annotationView.accy = self.trip.lastTripMotion.y;
                self.annotationView.accz = self.trip.lastTripMotion.z;
            }
        }
        [self.annotationView setNeedsDisplay];
    }

    if (self.trip) {
        if (self.trip.lastLocation) {
            AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
            NSInteger deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
            NSTimeInterval seconds = [self.trip.lastLocation.timestamp timeIntervalSinceDate:self.trip.startLocation.timestamp] - deferredSecs;
            NSInteger deferredMeters = [ad.defaults integerForKey:@"deferredMeters"];
            NSInteger meters = [self.trip.lastLocation distanceFromLocation:self.trip.startLocation] - deferredMeters;

            self.dummyButton.title = [NSString stringWithFormat:@"%@ / %ld m",
                                      hms(seconds),
                                      meters];
        } else {
            self.dummyButton.title = NSLocalizedString(@"Recording", @"Recording");
        }
    }

}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        self.annotationView = (AnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"me"];
        if (!self.annotationView) {
            self.annotationView = [[AnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"me"];
        }

        UIImage *image = [UIImage imageNamed:@"SimraSquare"];
        self.annotationView.personImage = image;

        self.annotationView.recording = self.trip != nil;
        self.annotationView.speed = 0.0;
        self.annotationView.course = 0.0;
        self.annotationView.accx = 0.0;
        self.annotationView.accy = 0.0;
        self.annotationView.accz = 0.0;
        [self.annotationView setNeedsDisplay];

        return self.annotationView;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    [self.mapView deselectAnnotation:self.myAnnotation animated:FALSE];
    if (self.trip) {
        [self stopButtonPressed:nil];
    } else {
        [self playButtonPressed:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (!sender) {
        if ([segue.destinationViewController isKindOfClass:[MyTripsTVC class]]) {
            MyTripsTVC *myTripsTVC = (MyTripsTVC *)segue.destinationViewController;
            myTripsTVC.preselectedTrip = self.recordedTrip;
        }
    }
}
@end
