//
//  UploaderObject.h
//  SimRa
//
//  Created by Christoph Krey on 04.04.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UploaderObject : NSObject <NSURLSessionDelegate>
@property (nonatomic) NSInteger version;
@property (nonatomic) Boolean edited;
@property (nonatomic) Boolean uploaded;
@property (strong, nonatomic) NSString *fileHash;
@property (strong, nonatomic) NSString *filePasswd;

- (NSURL *)csvFile;
- (void)save;
- (void)uploadWithController:(id)controller error:(SEL)error completion:(SEL)completion;

@end

NS_ASSUME_NONNULL_END
