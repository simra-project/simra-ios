//
//  OpenBikeSensorConfigurationViewController.m
//  SimRa
//
//  Created by Hamza Khan on 23/06/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "OpenBikeSensorConfigurationViewController.h"
#import "AppDelegate.h"
#import "SimRa-Swift.h"
#import "DeviceTableViewCell.h"
#import <Loaf/Loaf-Swift.h>
#import <TTGSnackbar/TTGSnackbar-Swift.h>
#import <math.h>

#define HEIGHT_DEVICE_VIEW 100
//@import TTG
@interface OpenBikeSensorConfigurationViewController (){
    BOOL testing;
    CBCharacteristic * sensorCharacteristic;
    CBCharacteristic * offSetCharacteristic;
    
    NSData *data;
    NSMutableArray *values;
//    TTGSnackbar * ttg;
    
}
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *devicesHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *scanningView;
@property (weak, nonatomic) IBOutlet UIView *offsetView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *deviceNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;

//@property (weak, nonatomic) IBOutlet UIPickerView *pickerViewDistance;
//@property (strong, nonatomic) NSMutableArray *distanceArr;
@property CBUUID *oBSServiceUUID;
@property CBUUID *closeByCharacteristicCBUUID;
@property CBUUID *sensorDistanceCharacteristicCBUUID;
@property CBUUID *offsetCharacteristicCBUUID;
@property CBUUID *timeCharacteristicCBUUID;
@property CBUUID *trackIdCharacteristicCBUUID;
@property (strong, nonatomic) NSMutableArray *discoveredDevices;
@property (strong, nonatomic) NSMutableArray *discoveredDummyDevices;
@property (weak, nonatomic) IBOutlet UITableView *devicesTableView;
@property (weak, nonatomic) IBOutlet UILabel *offsetSensorLeftLabel;
@property (weak, nonatomic) IBOutlet UILabel *offsetSensorRightLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *barProgressView;


@end

@implementation OpenBikeSensorConfigurationViewController 
@synthesize bleManager, scanningView, offsetView, devicesHeightConstraint;
- (void)viewDidLoad {
    [super viewDidLoad];
    _activityIndicator.hidesWhenStopped = YES;
    _discoveredDevices = [[NSMutableArray alloc]init];
    _discoveredDummyDevices = [[NSMutableArray alloc]initWithObjects:@"Hello", @"Testing", @"1", @"2" , nil];
    testing = NO;
//    [self.pickerViewDistance setHidden:true];
//    [self setupPickerViewDataSource];
    [self initOBSServiceCharacteristicsUUIDs];
    values =  [[NSMutableArray alloc]init];
    [self.barProgressView setTransform:CGAffineTransformMakeScale(1.0, 3.0)];

}

- (void)viewWillAppear:(BOOL)animated{
    [self setupBluetooth];
}
-(void)initOBSServiceCharacteristicsUUIDs {
    self.oBSServiceUUID = [CBUUID UUIDWithString:@"1FE7FAF9-CE63-4236-0004-000000000000"];
    self.sensorDistanceCharacteristicCBUUID = [CBUUID UUIDWithString: @"1FE7FAF9-CE63-4236-0004-000000000002"];
    self.offsetCharacteristicCBUUID = [CBUUID UUIDWithString: @"1FE7FAF9-CE63-4236-0004-000000000004"];

}
-(void)dealloc{
}
- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"Scanning stopped");

    [bleManager stopScanPeripheral];
    [self.bleManager setNotificationWithEnable:NO forCharacteristic:sensorCharacteristic];

    [super viewWillDisappear:animated];
}
-(void)setupBluetooth{
    bleManager = [BluetoothManager getInstance];
    bleManager.delegate = self;
    if (bleManager.connected != true){
        devicesHeightConstraint.constant = HEIGHT_DEVICE_VIEW;
        [self.activityIndicator startAnimating];
        [bleManager startScanPeripheral];
        [self.devicesTableView reloadData];
        [scanningView setHidden:NO];
        [offsetView setHidden:YES];
    }
    else{
        devicesHeightConstraint.constant = 0;
        [scanningView setHidden:YES];
        [offsetView setHidden:NO];
        sensorCharacteristic = [bleManager getSpecificCharacteristic:_oBSServiceUUID :@"1FE7FAF9-CE63-4236-0004-000000000002"];
        if (sensorCharacteristic != nil){
            [self.bleManager setNotificationWithEnable:YES forCharacteristic:sensorCharacteristic];
        }
    }
    [self.view layoutIfNeeded];
}

#pragma mark -
#pragma mark - Custom functions

- (IBAction)disconnectButtonPressed:(UIButton *)sender {
    [scanningView setHidden:NO]; // no means show // yes means hide
    [offsetView setHidden:YES]; // no means hide // yes means show
    devicesHeightConstraint.constant = HEIGHT_DEVICE_VIEW;
    [self.view layoutIfNeeded];
    if (bleManager.connectedPeripheral != nil){
        [bleManager disconnectPeripheral];
        [_discoveredDevices removeAllObjects];
    }
    

}
#pragma mark -
#pragma mark Custom Bluetooth Delegate


-(void)didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    PeripheralInfos *peripheralObj = [[PeripheralInfos alloc]init:peripheral];
    if (![self.discoveredDevices containsObject:peripheralObj]){
        peripheralObj.RSSI = RSSI.intValue;
        peripheralObj.advertisementData = advertisementData;
        [_discoveredDevices addObject:peripheralObj];
    }
    else{
        NSUInteger i = [_discoveredDevices indexOfObject:peripheralObj];
        PeripheralInfos *originalPeripheralObj = [_discoveredDevices objectAtIndex:i];
        NSTimeInterval timeInSeconds = [[NSDate date] timeIntervalSince1970];
        if (timeInSeconds - originalPeripheralObj.lastUpdatedTimeInterval >= 1.0){
            originalPeripheralObj.lastUpdatedTimeInterval = timeInSeconds;
            originalPeripheralObj.RSSI = RSSI.intValue;
            originalPeripheralObj.advertisementData = advertisementData;
        }
    }
    [_devicesTableView reloadData];
}

- (void)didUpdateState:(CBManagerState)state{
    if (state == CBManagerStateUnsupported){
        [self.bleManager stopScanPeripheral];;
        [_activityIndicator stopAnimating];
    }
    else if (state != CBManagerStatePoweredOn) {
        NSLog(@"Not on");
        return;
    }
    else{
        NSLog(@"start scanning");
        // Scan for devices
        [_activityIndicator startAnimating];
        [self.bleManager startScanPeripheral];
    }
    
}
- (void)didConnectedPeripheral:(CBPeripheral *)connectedPeripheral{
    NSLog(@"Connected to peripheral");
    [scanningView setHidden:YES];
    [offsetView setHidden:NO];
    devicesHeightConstraint.constant = 0;
    [self.view layoutIfNeeded];

}
-(void)didDiscoverCharacteritics:(CBService *)service{
    NSLog(@"Service.characteristics: %@", service.characteristics.description);
    [self.bleManager addCharacteristics:service];
    [self connectToSensorDistanceCharacteristic:service];
    [self connectToOffsetCharacteristic:service];
}
- (void)didDiscoverDescriptors:(CBCharacteristic *)characteristic{
    NSLog(@"CharacteristicController --> didDiscoverDescriptors");
    if ([characteristic.UUID.UUIDString isEqualToString:sensorCharacteristic.UUID.UUIDString]){
        sensorCharacteristic = characteristic;
    }
    else{
        if ([characteristic.UUID.UUIDString isEqualToString:sensorCharacteristic.UUID.UUIDString]){
            offSetCharacteristic = characteristic;
        }
    }
}
-(void)connectToOffsetCharacteristic:(CBService *)service{
    offSetCharacteristic = [self.bleManager getSpecificCharacteristic:service.UUID :self.offsetCharacteristicCBUUID.UUIDString];
    if (offSetCharacteristic != nil){
        [self.bleManager discoverDescriptor:offSetCharacteristic];
        [self.bleManager readValueForCharacteristicWithCharacteristic:offSetCharacteristic];
    }
}
-(void)connectToSensorDistanceCharacteristic:(CBService *)service{
    sensorCharacteristic = [self.bleManager getSpecificCharacteristic:service.UUID :_sensorDistanceCharacteristicCBUUID.UUIDString];
    if (sensorCharacteristic != nil){
        [self.bleManager discoverDescriptor:sensorCharacteristic];
        [self .bleManager setNotificationWithEnable:YES forCharacteristic:sensorCharacteristic];
    }
}
- (void)didReadValueForCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"CharacteristicController --> didReadValueForCharacteristic");
    NSArray<NSNumber *> *byteArray = [self.bleManager getByteArrayWithCharacteristic:characteristic];

    if ([characteristic.UUID.UUIDString isEqualToString:sensorCharacteristic.UUID.UUIDString]){
        NSLog(@"Sensor characteristic:");
        NSNumber *leftSensorVal = [self.bleManager compareLeftSensorLeastSignificantBitWithBytes:byteArray];// byteArray[4];
        NSNumber * rightSensorVal = [self.bleManager compareRightSensorLeastSignificantBitWithBytes:byteArray];//byteArray[6];
        [self setClosePassBarColorWithDistance:[leftSensorVal intValue]];
    }
    else {
        NSLog(@"Offset characteristic:");
        NSString *leftOffset = [NSString stringWithFormat:@"%@",byteArray[0]];
        NSString *rightOffset = [NSString stringWithFormat:@"%@",byteArray[2]];

        self.offsetSensorLeftLabel.text = leftOffset;
        self.offsetSensorRightLabel.text = rightOffset;

    }
    NSLog(@"Data: %@",byteArray);

}

- (void)didDiscoverServices:(CBPeripheral *)peripheral{
       [self.bleManager discoverCharacteristics];
    NSLog(@"%@", peripheral.services.description);
}
- (void)didFailedToInterrogate:(CBPeripheral *)peripheral{
    NSLog(@"FAILED");
}

#pragma mark -
#pragma mark TableView Delegate and Datasource and TableView Custom Functions

-(int)getRows{
    if (testing){
        return (int)[_discoveredDummyDevices count];
    }
    else if (_discoveredDevices.count == 0){
        return 1;
    }
    return (int)[_discoveredDevices count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self getRows];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    DeviceTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"deviceCell" forIndexPath:indexPath];
    if (testing){
        cell.deviceNameLabel.text = _discoveredDummyDevices[indexPath.row];
    }
    else{
        if ([_discoveredDevices count] == 0){
            [cell configEmptyCell:@"No devices found"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        else{
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            PeripheralInfos* peripheralInfo =  _discoveredDevices[indexPath.row];
            [cell configCell:peripheralInfo.peripheral row:(int)indexPath.row + 1];
            
        }
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
        [self showConfirmationToConnectForRow:(int)indexPath.row];
}

-(void)showConfirmationToConnectForRow:(int)row{
    if ([_discoveredDevices count] != 0 || testing == YES){
    [UIAlertController showAlertWithTitle:@"SimRa" message:@"Are you sure you want to connect with this device?" style:UIAlertControllerStyleAlert buttonFirstTitle:@"Return" buttonSecondTitle:@"Connect" buttonFirstAction:^{} buttonSecondAction:^{
        if (self->testing == NO){
        PeripheralInfos *peripheralInfo = self.discoveredDevices[row];
            [self.bleManager connectPeripheral:peripheralInfo.peripheral];
            [self.bleManager stopScanPeripheral];
            [self.activityIndicator stopAnimating];
        }
    } over:self];
    }
  
}
-(void)setClosePassBarColorWithDistance: (int)distance{
    NSLog(@"res: %.f", fmin(5,10));
    int maxColorValue = fmin(distance,200);
    float normalizedValue = maxColorValue / 2;
    float red = (255 * (100 - normalizedValue)) / 100;
    float green = (255 * normalizedValue) / 100;
    float blue = 0;
    UIColor * barColor = [UIColor colorWithRed:red green:green blue:blue alpha:1];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.barProgressView setProgressTintColor:[UIColor grayColor]];

        [self.barProgressView setProgress:(float)distance/255];
    });
}
@end
