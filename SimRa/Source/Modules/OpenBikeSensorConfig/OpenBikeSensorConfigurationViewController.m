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

    }
    [self.view layoutIfNeeded];

}

/*
-(void)setupPickerViewDataSource{
    self.distanceArr = [[NSMutableArray alloc]init];
    
    for (int i = 1 ; i <= 60 ; i ++){
        [self.distanceArr addObject: [NSNumber numberWithInt: i]];
    }
}

#pragma mark -
#pragma mark PickerView DataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    
        return [self.distanceArr count];
    
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
        return [NSString stringWithFormat:@"%@",[self.distanceArr objectAtIndex:row]];
}
#pragma mark -
#pragma mark PickerView Delegate

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row
      inComponent:(NSInteger)component
{
   
        NSString *resultString = [[NSString alloc] initWithFormat:
                                  @"Distance: %@",
                                  [self.distanceArr objectAtIndex:row]];
        NSLog(@"%@",resultString);
}

 */

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
//        [self.bleManager disconnectPeripheral];
        [_activityIndicator stopAnimating];
    }
    else if (state != CBManagerStatePoweredOn) {
        NSLog(@"Not on");
        return;
    }
    else{
        NSLog(@"start scanning");
//    if (state == CBManagerStatePoweredOn) {
        // Scan for devices
        [_activityIndicator startAnimating];
        [self.bleManager startScanPeripheral];
        
//
//        [_centralManager scanForPeripheralsWithServices:services options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
//        NSLog(@"Scanning started");
        
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
    offSetCharacteristic = [self.bleManager getSpecificCharacteristic:service :self.offsetCharacteristicCBUUID.UUIDString];
    if (offSetCharacteristic != nil){
        [self.bleManager discoverDescriptor:offSetCharacteristic];
        [self.bleManager readValueForCharacteristicWithCharacteristic:offSetCharacteristic];
    }
}
-(void)connectToSensorDistanceCharacteristic:(CBService *)service{
    sensorCharacteristic = [self.bleManager getSpecificCharacteristic:service :_sensorDistanceCharacteristicCBUUID.UUIDString];
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
        NSNumber *leftSensorVal = byteArray[4];
        NSNumber * rightSensorVal = byteArray[6];
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
//    cell.configCell
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
//    if ([_discoveredDevices count] != 0){
        [self showConfirmationToConnectForRow:(int)indexPath.row];
        
//    }
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
/*
 private void setClosePassBarColor(int distanceInCm) {
 int maxColorValue = Math.min(distanceInCm, 200); // 200 cm ist maximum, das grün
 // Algoritmus found https://stackoverflow.com/questions/340209/generate-colors-between-red-and-green-for-a-power-meter
 // Da n zwischen 0 -100 liegen soll und das maximum 200 ist, dann halbieren immer den Wert.
 int normalizedValue = maxColorValue / 2;
 int red = (255 * (100 - normalizedValue)) / 100;
 int green = (255 * normalizedValue) / 100;
 int blue = 0;
 // Color und Progress sind abhängig
 binding.progressBarClosePass.setProgressTintList(ColorStateList.valueOf(Color.rgb(red, green, blue)));
 binding.progressBarClosePass.setProgress(normalizedValue);
 }

 */

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
    
//    self.barProgressView.progress = 1;
}
/*
#pragma mark -
#pragma mark CoreBluetooth Delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // You should test all scenarios
    if (central.state != CBManagerStatePoweredOn) {
        NSLog(@"Not on");
        return;
    }
    
    if (central.state == CBManagerStatePoweredOn) {
        // Scan for devices
        [_activityIndicator startAnimating];
        NSArray *services = [NSArray arrayWithObjects:
                             _oBSServiceUUID,
                             nil];

        [_centralManager scanForPeripheralsWithServices:services options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        NSLog(@"Scanning started");
        
    }
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"%@", peripheral.name);
    _obsPeripheral = peripheral;
//    [_centralManager stopScan];
    [_discoveredDevices addObject:peripheral];
    [_devicesTableView reloadData];
    
//    [_centralManager connectPeripheral:_obsPeripheral options:nil];
//    _obsPeripheral.delegate = self;
//    1FE7FAF9-CE63-4236-0004-000000000000
//    if ([peripheral.name isEqualToString:@"OpenBikeSensor-84f8"]){
//        self.discoveredPeripheral = peripheral;
//        [_centralManager connectPeripheral:peripheral options:nil];
//    }
    
    //    2021-07-12 19:01:17.699742+0200 SimRa[8017:303480] <CBPeripheral: 0x282798be0, identifier = DD5C96C9-BB84-2CE8-63AB-8FD28E40175C, name = OpenBikeSensor-84f8, mtu = 0, state = disconnected>

}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"%@ connected",peripheral.name);
    [_centralManager stopScan];
    [_activityIndicator stopAnimating];

    // connecting to only obs service
    NSArray * services = [NSArray arrayWithObject:_oBSServiceUUID];
    [peripheral discoverServices:services];
}
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error{
//    for (CBCharacteristic *characteristic in service.characteristics){
//        if ([characteristic.UUID.UUIDString containsString:@"DD5C96C9"]){
//            NSLog(@"Here");
//            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//            break;
//        }
//    }
//
//}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    for (CBService *service in peripheral.services){
        NSLog(@"SERVICE: %@",service);
//
        [peripheral discoverCharacteristics:@[_sensorDistanceCharacteristicCBUUID] forService:service];
//        NSLog(@"CHARACTERISTICS %@",service.characteristics);
//        if ([service.UUID.UUIDString isEqualToString:@"DD5C96C9-BB84-2CE8-63AB-8FD28E40175C"]){
//            [peripheral discoverCharacteristics:nil forService:service];
//        }
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (service.characteristics == nil){
        return;
    }
    for (CBCharacteristic * characteristic in service.characteristics){
        if ([[characteristic.UUID UUIDString] isEqualToString:[_sensorDistanceCharacteristicCBUUID UUIDString]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//                        [peripheral readValueForCharacteristic:characteristic];

        }

//        if (characteristric.properties == CBCharacteristicPropertyRead){
//            NSLog(@"CHARACTERISTIC: %@ properties contain .read", characteristric);
////            [peripheral readValueForCharacteristic:characteristric];
//        }
//
//        if (characteristric.properties == CBCharacteristicPropertyNotify){
//            NSLog(@"CHARACTERISTIC: %@ properties contain .notify", characteristric);
////            [peripheral readValueForCharacteristic:characteristric];
//            NSLog(@"CHARACTERISTIC UUID: %@", characteristric.UUID);
//            NSLog(@"Sensor Distance CHARACTERISTIC UUID: %@", _sensorDistanceCharacteristicCBUUID.UUIDString);
//
////            if (characteristric.UUID == _sensorDistanceCharacteristicCBUUID){
//                [peripheral setNotifyValue:YES forCharacteristic:characteristric];
////            }
//        }
    }
}
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
//    if ([[characteristic.UUID UUIDString] isEqualToString:_sensorDistanceCharacteristicCBUUID.UUIDString]){
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"sensorDistance VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//    else if ([[characteristic.UUID UUIDString] isEqualToString: _closeByCharacteristicCBUUID.UUIDString]){
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"CLOSEBY VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//    else if ([[characteristic.UUID UUIDString] isEqualToString: _timeCharacteristicCBUUID.UUIDString]){
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"Time VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//    else if ([[characteristic.UUID UUIDString] isEqualToString: _offsetCharacteristicCBUUID.UUIDString]){
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"Offset VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//    else if ([[characteristic.UUID UUIDString] isEqualToString: _trackIdCharacteristicCBUUID.UUIDString]){
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"track VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//    else{
//        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"Other VALUE OF CHARACTERISTIC: %@", stringFromData);
//    }
//
//}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error");
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            NSLog(@"Other VALUE OF CHARACTERISTIC: %@", stringFromData);

    // Have we got everything we need?
//    if ([stringFromData isEqualToString:@"EOM"]) {
//
//        [_textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
//
//        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
//
//        [_centralManager cancelPeripheralConnection:peripheral];
//    }
//
//    [_data appendData:characteristic.value];
}


-(NSString *)getData:(CBCharacteristic *)characteristic{
    return @"";
}
 */
@end
