//
//  OpenBikeSensorConfigurationViewController.h
//  SimRa
//
//  Created by Hamza Khan on 23/06/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SimRa-Swift.h"
NS_ASSUME_NONNULL_BEGIN

@interface OpenBikeSensorConfigurationViewController : UIViewController<UIPickerViewDelegate, UIPickerViewDataSource,UITableViewDelegate, UITableViewDataSource, BluetoothDelegate, CBPeripheralDelegate>
@property (nonatomic) BluetoothManager *bleManager;
//@property (strong, nonatomic) CBCentralManager *centralManager;
//@property (strong, nonatomic) CBPeripheral *obsPeripheral;

@end

NS_ASSUME_NONNULL_END
