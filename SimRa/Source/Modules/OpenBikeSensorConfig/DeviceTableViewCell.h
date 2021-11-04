//
//  DeviceTableViewCell.h
//  SimRa
//
//  Created by Hamza Khan on 14/07/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *deviceNameLabel;
-(void)configCell:(CBPeripheral *)peripheral row:(int)row;
-(void)configEmptyCell:(NSString *)str;
@end

NS_ASSUME_NONNULL_END
