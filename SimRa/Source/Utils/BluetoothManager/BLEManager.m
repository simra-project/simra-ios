//
//  BLEManager.m
//  SimRa
//
//  Created by Hamza Khan on 15/07/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "BLEManager.h"

@implementation BLEManager
@synthesize someProperty;

#pragma mark Singleton Methods

+ (id)sharedManager {
    static BLEManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
        someProperty = @"Default Property Value";
    }
    return self;
}

- (void)dealloc {
    // Should never be called, bu
}
@end
