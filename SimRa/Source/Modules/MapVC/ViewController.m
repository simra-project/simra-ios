//
//  ViewController.m
//  simra
//
//  Created by Christoph Krey on 27.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Trips.h"
#import "AnnotationView.h"
#import "NSTimeInterval+hms.h"
#import "MyTripsTVC.h"
#import "News.h"
#import "Regions.h"
#import "BLEManager.h"
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
{
    CBCharacteristic * closePassCharacteristic;
    CBUUID *closePassCharacteristicCBUUID;

}
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *dummyButton;

@property (strong, nonatomic) MKUserTrackingButton *trackingButton;
@property (strong, nonatomic) Trip *trip;
@property (strong, nonatomic) Trip *recordedTrip;

@property (strong, nonatomic) AnnotationView *annotationView;
@property (strong, nonatomic) MyAnnotation *myAnnotation;

@property (strong, nonatomic) UIAlertController *ac;
@property (nonatomic) NSInteger queued;
@property (strong, nonatomic) UIButton *openBikeSensorConfigButton;

@property (nonatomic) BOOL initialMessagePassed;

@end

@implementation ViewController
@synthesize bleManager;
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
                                                            toItem:self.view.safeAreaLayoutGuide
                                                         attribute:NSLayoutAttributeBottom
                                                        multiplier:1
                                                          constant:-10];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.trackingButton
                                                         attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                            toItem:self.view.safeAreaLayoutGuide
                                                         attribute:NSLayoutAttributeTrailing
                                                        multiplier:1
                                                          constant:-10];

    [NSLayoutConstraint activateConstraints:@[a, b]];
    [self setupOpenBikeSensor];
    self.playButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
    self.navigationItem.leftBarButtonItem.enabled = TRUE;
    self.navigationItem.rightBarButtonItem.enabled = TRUE;

    self.dummyButton.title = NSLocalizedString(@"Not Recording", @"Not Recording");

    AppDelegate *ad = [AppDelegate sharedDelegate];
    

    [ad.news addObserver:self
              forKeyPath:@"newsVersion"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    [ad.regions addObserver:self
                 forKeyPath:@"loaded"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    [self setupBluetooth];

//    bleManager = BluetoothManager.shared;
    
//    NSLog(@"%@",test.someProperty);
}
-(void)setupBluetooth{
    bleManager = [BluetoothManager getInstance];
    if (bleManager.connectedPeripheral != nil){
        [bleManager disconnectPeripheral];
    }
    closePassCharacteristicCBUUID = [CBUUID UUIDWithString: @"1FE7FAF9-CE63-4236-0004-000000000003"];
}
-(void)setupConnectedBluetoothDevice{
    if ([self.bleManager connected]){
        [self.bleManager showConnectedState];
        bleManager.delegate = self;
        NSArray *serviceArr = [NSArray arrayWithObject:closePassCharacteristicCBUUID];
        [self.bleManager.connectedPeripheral discoverServices:serviceArr];
    }
}
-(void)viewDidDisappear:(BOOL)animated{
}
-(void)viewWillAppear:(BOOL)animated{
    AppDelegate *ad = [AppDelegate sharedDelegate];
    BOOL showHideOpenBikeSensor = [ad.defaults boolForKey:@"openBikeSensor"];
    [self showHideOpenBikeSensorConfigButton:showHideOpenBikeSensor];
    [self setupConnectedBluetoothDevice];
}
- (void)viewDidAppear:(BOOL)animated {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    //[ad.defaults setBool:FALSE forKey:@"initialMessage"];
    if (![ad.defaults boolForKey:@"initialMessage"]) {
//        [ad.defaults setBool:TRUE forKey:@"initialMessage"];
        [Utility saveBoolWithKey:@"initialMessage" value:TRUE];

        self.ac = [UIAlertController
                   alertControllerWithTitle:NSLocalizedString(@"How To", @"How To")
                   message:[NSString stringWithFormat:@"%@\n\n%@",
                            NSLocalizedString(@"Would you like to view the User Manual now?", @"Would you like to view the User Manual now?"),
                            NSLocalizedString(@"If not, you may access it via Settings/How To later", @"If not, you may access it via Settings/How To")
                            ]
                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [ad showHowTo];
            self.initialMessagePassed = TRUE;
            [self checkRegions];
        }];
        [self.ac addAction:aay];

        UIAlertAction *aac = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                      style:UIAlertActionStyleCancel
                                                    handler:^(UIAlertAction * _Nonnull action) {
            self.initialMessagePassed = TRUE;
            [self checkRegions];
        }];
        [self.ac addAction:aac];
        [self presentViewController:self.ac animated:TRUE completion:nil];
    } else {
        self.initialMessagePassed = TRUE;
        [self checkRegions];
    }
}
-(void)setupOpenBikeSensor{
    self.openBikeSensorConfigButton = [[UIButton alloc]init];
    self.openBikeSensorConfigButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.openBikeSensorConfigButton setBackgroundImage:[UIImage imageNamed:@"bluetooth"] forState:UIControlStateNormal];
    [self.openBikeSensorConfigButton addTarget:self action:@selector(didTapOnOBSConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.openBikeSensorConfigButton];
    NSLayoutConstraint *bottomConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                           attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.view.safeAreaLayoutGuide
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1
                                                                            constant:-70];
    NSLayoutConstraint *trainlingConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                              attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                                                 toItem:self.view.safeAreaLayoutGuide
                                                                              attribute:NSLayoutAttributeTrailing
                                                                             multiplier:1
                                                                               constant:-10];
    NSLayoutConstraint *widthConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                          attribute:NSLayoutAttributeWidth
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:nil
                                                                          attribute: NSLayoutAttributeNotAnAttribute
                                                                         multiplier:1
                                                                           constant:40];
    NSLayoutConstraint *heightConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                           attribute:NSLayoutAttributeHeight
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:nil
                                                                           attribute: NSLayoutAttributeNotAnAttribute
                                                                          multiplier:1
                                                                            constant:40];
    
    [NSLayoutConstraint activateConstraints:@[bottomConstraintOBS,trainlingConstraintOBS,widthConstraintOBS,heightConstraintOBS]];
}
-(void)didTapOnOBSConfig{
    [self performSegueWithIdentifier:@"obsConfig" sender:self];
    
}
-(void)showHideOpenBikeSensorConfigButton:(BOOL)showBtn{
    [self.openBikeSensorConfigButton setHidden:!showBtn];
}
- (void)checkRegions {
    if (!self.initialMessagePassed) {
        return;
    }
    AppDelegate *ad = [AppDelegate sharedDelegate];
    if (!ad.regions.loaded) {
        return;
    }

    if ([ad.defaults boolForKey:@"suppressRegionMessage"]) {
        return;
    }

    if (ad.regions.closestsRegions) {
        return;
    }

    CLLocation *myLocation = self.mapView.userLocation.location;
    [ad.regions computeClosestsRegions:myLocation];

    if (![ad.defaults boolForKey:@"onceRegionMessage"] ||
        (ad.regions.regionsId > ad.regions.lastSeenRegionsId &&
            (ad.regions.regionId == 0 || [ad.regions.currentRegion.identifier isEqualToString:@"other"])
         ) || !ad.regions.selectedIsOneOfThe3ClosestsRegions) {
//        [ad.defaults setBool:TRUE forKey:@"onceRegionMessage"];
        [Utility saveBoolWithKey:@"onceRegionMessage" value:TRUE];

        [ad.regions seen];

        NSString *message = [NSString stringWithFormat:@"%@ %@",
                             NSLocalizedString(@"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:",
                                                       @"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:"),
                             ad.regions.regionId == 0 ? ad.regions.currentRegion.identifier : ad.regions.currentRegion.localizedDescription];
        self.ac = [UIAlertController
                   alertControllerWithTitle:NSLocalizedString(@"Please choose a Region",
                                                              @"Please choose a Region")
                   message: message
                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aad = [UIAlertAction actionWithTitle:NSLocalizedString(@"Don't show this again",
                                                                              @"Don't show this again")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
//            [ad.defaults setBool:TRUE forKey:@"suppressRegionMessage"];
            [Utility saveBoolWithKey:@"suppressRegionMessage" value:TRUE];

        }];
        [self.ac addAction:aad];

        UIAlertAction *aal = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"Later")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
        [self.ac addAction:aal];

        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [self performSegueWithIdentifier:@"editRegion" sender:nil];
        }];
        [self.ac addAction:aay];

        [self presentViewController:self.ac animated:TRUE completion:nil];
    }
}

- (IBAction)playButtonPressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
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

    UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Incident Detection Running", @"Incident Detection Running")
                                 message:NSLocalizedString(@"Please wait", @"Please wait")
                                 preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:ac animated:TRUE completion:nil];
    [self.trip stopRecording];
    [ac dismissViewControllerAnimated:TRUE completion:nil];
    
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

    if ([keyPath isEqualToString:@"lastLocation"] ||
        [keyPath isEqualToString:@"lastTripMotion"]) {
        [self performSelectorOnMainThread:@selector(update)
                               withObject:nil
                            waitUntilDone:NO];
        self.queued++;
        //NSLog(@"Queued I: %ld", (long)self.queued);
    }

    if ([keyPath isEqualToString:@"newsVersion"]) {
        [self performSegueWithIdentifier:@"showNews" sender:nil];
    }

    if ([keyPath isEqualToString:@"loaded"]) {
        [self performSelectorOnMainThread:@selector(checkRegions)
                               withObject:nil
                            waitUntilDone:NO];
    }
}

- (IBAction)newsSeen:(UIStoryboardSegue *)unwindSegue {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.news seen];
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)update {
    self.queued--;
//    NSLog(@"Queued O: %ld", (long)self.queued);

    if (!self.queued) {
        if (self.annotationView) {
            self.annotationView.recording = self.trip != nil;
            if (self.trip) {
                if (self.trip.lastLocation) {
                    
//                    NSLog(@"update lastLocation %f", self.trip.lastLocation.coordinate.latitude);
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
                AppDelegate *ad = [AppDelegate sharedDelegate];
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

# pragma mark -
# pragma mark - Core Bluetooth

-(void)didDiscoverCharacteritics:(CBService *)service{
    [self connectToClosePassCharacteristic:service];
}
-(void)connectToClosePassCharacteristic:(CBService *)service{
    closePassCharacteristic = [self.bleManager getSpecificCharacteristic:service.UUID :closePassCharacteristicCBUUID.UUIDString];
    if (closePassCharacteristic != nil){
        [self.bleManager discoverDescriptor:closePassCharacteristic];
        [self .bleManager setNotificationWithEnable:YES forCharacteristic:closePassCharacteristic];

    }
}
- (void)didDiscoverDescriptors:(CBCharacteristic *)characteristic{
    NSLog(@"CharacteristicController --> didDiscoverDescriptors");
    
    if ([characteristic.UUID.UUIDString isEqualToString:closePassCharacteristic.UUID.UUIDString]){
        closePassCharacteristic = characteristic;
    }
}

- (void)didReadValueForCharacteristic:(CBCharacteristic *)characteristic{
//    NSLog(@"CharacteristicController --> didReadValueForCharacteristic");
    NSArray<NSNumber *> *byteArray = [self.bleManager getByteArrayWithCharacteristic:characteristic];
    
    if ([characteristic.UUID.UUIDString isEqualToString:closePassCharacteristic.UUID.UUIDString]){
//        NSLog(@"closs pass characteristic:");
//        NSLog(@"Data: %@",byteArray);
        
        NSNumber * leftSensor = [self.bleManager compareLeftSensorLeastSignificantBitWithBytes:byteArray];
        
        NSNumber * rightSensor = [self.bleManager compareRightSensorLeastSignificantBitWithBytes:byteArray];
//        NSLog(@"LEFT SENSOR: %@",leftSensor);
//        NSLog(@"RIGHT SENSOR: %@",rightSensor);
        if (!self.playButton.isEnabled){
            [self.trip storeClosePassValueForTripWithLeftSensorVal:leftSensor rightSensorVal:rightSensor];
        }

    }
    
}
- (void)didDiscoverServices:(CBPeripheral *)peripheral{
    [self.bleManager discoverCharacteristics];
}

@end
