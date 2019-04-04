//
//  Trips.h
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Trip.h"

NS_ASSUME_NONNULL_BEGIN

@interface Trips : NSObject <NSURLSessionDelegate>
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, Trip *> *trips;
@property (nonatomic) NSInteger version;
@property (nonatomic) BOOL uploaded;
@property (strong, nonatomic) NSString *fileHash;
@property (strong, nonatomic) NSString *filePasswd;


- (Trip *)newTrip;
- (void)deleteTripWithIdentifier:(NSInteger)identifier;
- (void)addTripToStatistics:(Trip *)trip;
- (void)uploadWithController:(id)controller error:(SEL)error completion:(SEL)completion;

@end

NS_ASSUME_NONNULL_END
