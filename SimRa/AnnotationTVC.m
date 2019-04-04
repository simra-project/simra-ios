//
//  AnnotationTVC.m
//  SimRa
//
//  Created by Christoph Krey on 29.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "AnnotationTVC.h"
#import "IdPicker.h"
#import "AppDelegate.h"

@interface AnnotationTVC ()
@property (weak, nonatomic) IBOutlet IdPicker *incident;
@property (weak, nonatomic) IBOutlet UISwitch *frightened;
@property (weak, nonatomic) IBOutlet UISwitch *car;
@property (weak, nonatomic) IBOutlet UISwitch *taxi;
@property (weak, nonatomic) IBOutlet UISwitch *van;
@property (weak, nonatomic) IBOutlet UISwitch *bus;
@property (weak, nonatomic) IBOutlet UISwitch *lorry;
@property (weak, nonatomic) IBOutlet UISwitch *pedestrian;
@property (weak, nonatomic) IBOutlet UISwitch *bike;
@property (weak, nonatomic) IBOutlet UISwitch *motorbike;
@property (weak, nonatomic) IBOutlet UISwitch *other;
@property (weak, nonatomic) IBOutlet UITextView *comment;


@end

@implementation AnnotationTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.comment.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.incident.array = [ad.constants mutableArrayValueForKey:@"incidents"];

    [self update];
}

- (void)update {
    self.incident.arrayIndex = self.tripAnnotation.incidentId;
    self.frightened.on = self.tripAnnotation.frightening;
    self.car.on = self.tripAnnotation.car;
    self.bus.on = self.tripAnnotation.bus;
    self.lorry.on = self.tripAnnotation.commercial;
    self.van.on = self.tripAnnotation.delivery;
    self.taxi.on = self.tripAnnotation.taxi;
    self.bike.on = self.tripAnnotation.bicycle;
    self.motorbike.on = self.tripAnnotation.motorcycle;
    self.pedestrian.on = self.tripAnnotation.pedestrian;
    self.other.on = self.tripAnnotation.other;
    self.comment.text = self.tripAnnotation.comment;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    self.tripAnnotation.comment = textView.text;
}

- (IBAction)incidentChanged:(IdPicker *)sender {
    self.tripAnnotation.incidentId = sender.arrayIndex;
}

- (IBAction)frighteningChanged:(UISwitch *)sender {
    self.tripAnnotation.frightening = sender.on;
}
- (IBAction)carChanged:(UISwitch *)sender {
    self.tripAnnotation.car = sender.on;
}
- (IBAction)taxiChanged:(UISwitch *)sender {
    self.tripAnnotation.taxi = sender.on;
}
- (IBAction)vanChanged:(UISwitch *)sender {
    self.tripAnnotation.delivery = sender.on;
}
- (IBAction)busChanged:(UISwitch *)sender {
    self.tripAnnotation.bus = sender.on;
}
- (IBAction)lorryChanged:(UISwitch *)sender {
    self.tripAnnotation.commercial = sender.on;
}
- (IBAction)pedestrianChanged:(UISwitch *)sender {
    self.tripAnnotation.pedestrian = sender.on;
}
- (IBAction)bikeChanged:(UISwitch *)sender {
    self.tripAnnotation.bicycle = sender.on;
}
- (IBAction)motorbikeChanged:(UISwitch *)sender {
    self.tripAnnotation.motorcycle = sender.on;
}
- (IBAction)otherChanged:(UISwitch *)sender {
    self.tripAnnotation.other = sender.on;
}
- (IBAction)commentDonePressed:(UIButton *)sender {
    [self.comment resignFirstResponder];
}

@end
