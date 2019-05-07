//
//  TripDetailTVC.m
//  SimRa
//
//  Created by Christoph Krey on 02.05.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "TripDetailTVC.h"
#import "IdPicker.h"
#import "AppDelegate.h"

@interface TripDetailTVC ()
@property (weak, nonatomic) IBOutlet IdPicker *bikeType;
@property (weak, nonatomic) IBOutlet IdPicker *position;
@property (weak, nonatomic) IBOutlet UISwitch *childSeat;
@property (weak, nonatomic) IBOutlet UISwitch *trailer;

@end

@implementation TripDetailTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    self.bikeType.array = [ad.constants mutableArrayValueForKey:@"bikeTypes"];
    self.position.array = [ad.constants mutableArrayValueForKey:@"positions"];

    self.bikeType.arrayIndex = self.trip.bikeTypeId;
    self.position.arrayIndex = self.trip.positionId;
    self.childSeat.on = self.trip.childseat;
    self.trailer.on = self.trip.trailer;
}


@end
