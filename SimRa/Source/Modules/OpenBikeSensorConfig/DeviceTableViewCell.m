//
//  DeviceTableViewCell.m
//  SimRa
//
//  Created by Hamza Khan on 14/07/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "DeviceTableViewCell.h"
@implementation DeviceTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}
-(void)configCell:(CBPeripheral *)peripheral{
    self.deviceNameLabel.text = peripheral.name;
}
-(void)configEmptyCell:(NSString *)str{
    self.deviceNameLabel.text = str;
}

@end
