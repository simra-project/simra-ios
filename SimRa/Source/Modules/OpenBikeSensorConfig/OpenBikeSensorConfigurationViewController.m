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

@interface OpenBikeSensorConfigurationViewController (){
    BOOL testing;
}
@property (weak, nonatomic) IBOutlet UIPickerView *pickerViewScreenshotTimer;
@property (weak, nonatomic) IBOutlet UISwitch *switchPictures;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIPickerView *pickerViewDistance;
@property (strong, nonatomic) NSMutableArray *distanceArr;
@property (strong, nonatomic) NSMutableArray *timerArr;
@property CBUUID *oBSServiceUUID;
@property CBUUID *closeByCharacteristicCBUUID;
@property CBUUID *sensorDistanceCharacteristicCBUUID;
@property CBUUID *timeCharacteristicCBUUID;
@property CBUUID *offsetCharacteristicCBUUID;
@property CBUUID *trackIdCharacteristicCBUUID;
@property (strong, nonatomic) NSMutableArray *discoveredDevices;
@property (strong, nonatomic) NSMutableArray *discoveredDummyDevices;

@property (weak, nonatomic) IBOutlet UITableView *devicesTableView;


@end

@implementation OpenBikeSensorConfigurationViewController 
@synthesize bleManager;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _activityIndicator.hidesWhenStopped = YES;
    _discoveredDevices = [[NSMutableArray alloc]init];
    _discoveredDummyDevices = [[NSMutableArray alloc]initWithObjects:@"Hello", @"Testing", @"1", @"2" , nil];
    testing = NO;
    [self setupPickerViewDataSource];
    [self update];
}

- (void)viewWillAppear:(BOOL)animated{
    [self setupBluetooth];
    [self.devicesTableView reloadData];

}
-(void)dealloc{
}
- (void)viewWillDisappear:(BOOL)animated {
    
//    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    [bleManager stopScanPeripheral];
//    [bleManager removeMultipleDelegateInstance:self];
    [super viewWillDisappear:animated];
}
-(void)setupBluetooth{
    bleManager = [BluetoothManager getInstance];
    [bleManager initCBCentralManager];
    bleManager.delegate = self;
//    NSMutableArray *delegates = [bleManager.delegates mutableCopy];
//    [delegates addObject:self];
//    bleManager.delegates = [delegates copy];
    if (bleManager.connectedPeripheral != nil){
        [bleManager disconnectPeripheral];
    }
}
-(void)update{
    AppDelegate *ad = [AppDelegate sharedDelegate];
    BOOL showPicker = ![Utility getValWithKey:@"hidePicturePicker"];

    self.switchPictures.on = showPicker;

}
-(void)setupPickerViewDataSource{
    self.distanceArr = [[NSMutableArray alloc]init];
    self.timerArr = [[NSMutableArray alloc]init];

    for (int i = 1 ; i <= 60 ; i ++)
    {
        [self.distanceArr addObject: [NSNumber numberWithInt: i]];
    }
    for (int i = 1 ; i <= 10 ; i ++)
    {
        [self.timerArr addObject: [NSNumber numberWithInt: i]];
    }
}

#pragma mark -
#pragma mark PickerView DataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    
    if (pickerView == self.pickerViewDistance) {
        return [self.distanceArr count];
    }
    return [self.timerArr count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    if (pickerView == self.pickerViewDistance) {
        return [NSString stringWithFormat:@"%@",[self.distanceArr objectAtIndex:row]];
    }
    return [NSString stringWithFormat:@"%@",[self.timerArr objectAtIndex:row]];
}
#pragma mark -
#pragma mark PickerView Delegate

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row
      inComponent:(NSInteger)component
{
    if (pickerView == self.pickerViewDistance)
    {
        NSString *resultString = [[NSString alloc] initWithFormat:
                                  @"Distance: %@",
                                  [self.distanceArr objectAtIndex:row]];
        NSLog(@"%@",resultString);
    } else {
        NSString *resultString = [[NSString alloc] initWithFormat:
                                  @"Time: %@",
                                  [self.timerArr objectAtIndex:row]];
        NSLog(@"%@",resultString);

    }
}
- (IBAction)screenShotPickerValueChanged:(UISwitch *)sender {
    BOOL showPicker = sender.on;
    [Utility saveBoolWithKey:@"hidePicturePicker" value:showPicker];

    [self.pickerViewScreenshotTimer setHidden:!showPicker];
    
}

#pragma mark -
#pragma mark Custom Bluetooth Delegate


-(void)didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"%@", peripheral.name);
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

//    _obsPeripheral = peripheral;
    
    //    [_centralManager connectPeripheral:_obsPeripheral options:nil];
    //    _obsPeripheral.delegate = self;
    //    1FE7FAF9-CE63-4236-0004-000000000000
    //    if ([peripheral.name isEqualToString:@"OpenBikeSensor-84f8"]){
    //        self.discoveredPeripheral = peripheral;
    //        [_centralManager connectPeripheral:peripheral options:nil];
    //    }
    
    //    2021-07-12 19:01:17.699742+0200 SimRa[8017:303480] <CBPeripheral: 0x282798be0, identifier = DD5C96C9-BB84-2CE8-63AB-8FD28E40175C, name = OpenBikeSensor-84f8, mtu = 0, state = disconnected>

}

- (void)didUpdateState:(CBManagerState)state{
    if (state == CBManagerStateUnsupported){
        [self.bleManager stopScanPeripheral];;
        [self.bleManager disconnectPeripheral];
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
}
- (void)didDiscoverServices:(CBPeripheral *)peripheral{
    NSLog(@"%@", peripheral.services.description);
//    PeripheralInfos *temp = [[PeripheralInfos alloc]init:peripheral];
//    NSUInteger i = [_discoveredDevices indexOfObject:temp];
    [bleManager discoverCharacteristics];
    NSLog(@"Name of connected device %@",bleManager.connectedPeripheral.name);
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
            [cell configCell:peripheralInfo.peripheral];
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
////        [self.centralManager cancelPeripheralConnection:self.obsPeripheral];
////        self.obsPeripheral = peripheral;
////        [self.centralManager connectPeripheral:self.obsPeripheral options:nil];
//            NSString * message = [NSString stringWithFormat:@"%@ device is connected",peripheral.name];
//            [UIAlertController showAlertWithTitle:@"SimRa" message:message style:UIAlertControllerStyleAlert buttonFirstTitle:@"Ok" buttonFirstAction:^{} over:self];
        }
    } over:self];
    }
  
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
