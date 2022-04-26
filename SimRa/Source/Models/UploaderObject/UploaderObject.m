//
//  UploaderObject.m
//  SimRa
//
//  Created by Christoph Krey on 04.04.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "UploaderObject.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"
#import "SimRa-Swift.h"
#import "API.h"

@interface UploaderObject ()

@end

@implementation UploaderObject

- (instancetype)init {
    self = [super init];
    self.version = 1;
    return self;
}

- (NSURL *)csvFile {
    return nil; // must override
}

- (void)save {
    // must override
}
//second
- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    NSURL *csvFile = self.csvFile;

    NSData *data = [NSData dataWithContentsOfURL:csvFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"data:\n%@", string);

    AppDelegate *ad = [AppDelegate sharedDelegate];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    if (self.fileHash && self.filePasswd) {
        if ([self.fileHash  isEqual: @""] || [self.filePasswd  isEqual: @""]){
            NSArray *keyPass = [Utility getKeyPasswrdForRegion];
            self.fileHash = keyPass[0];
            self.filePasswd = keyPass[1];
        }
        urlString = [NSString stringWithFormat:@"%@/%@?fileHash=%@&filePassword=%@&loc=%@&clientHash=%@",
                     API.APIPrefix,
                     name,
                     self.fileHash,
                     self.filePasswd,
                     ad.regions.currentRegion.identifier,
                     NSString.clientHash];
        [request setHTTPMethod:@"PUT"];
    } else {
        urlString = [NSString stringWithFormat: @"%@/%@?loc=%@&clientHash=%@",
                     API.APIPrefix,
                     name,
                     ad.regions.currentRegion.identifier,
                     NSString.clientHash];
        [request setHTTPMethod:@"POST"];
    }
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    [request setURL:[NSURL URLWithString:urlString]];

    [request setValue:@"text/plain" forHTTPHeaderField: @"Content-Type"];
    [request setTimeoutInterval:10.0];
    NSLog(@"request:\n%@", request);

    NSURLSessionUploadTask *dataTask =
    [
     [NSURLSession sharedSession]
     uploadTaskWithRequest:request
     fromFile:csvFile
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *connectionError) {

         if (connectionError) {
             NSLog(@"connectionError %@", connectionError);
             [controller performSelectorOnMainThread:error
                                          withObject:connectionError
                                       waitUntilDone:NO];
         } else {
             NSLog(@"response %@ %@",
                   response,
                   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     if ([request.HTTPMethod isEqualToString:@"POST"]) {
                         NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                         NSArray <NSString *> *components = [dataString componentsSeparatedByString:@","];
                         if (components.count == 2) {
                             self.fileHash = components[0];
                             self.filePasswd = components[1];
                             // store here keys and password
                             NSString *key = [NSString stringWithFormat:@"Profile_%ld",(long)ad.regions.regionId];
                             NSString *value = [NSString stringWithFormat:@"%@,%@",self.fileHash,self.filePasswd];
                             [Utility writeToKeyPrefsWithKey:key val:value];
                         }
                     }
                     self.version++;
                     self.uploaded = TRUE;
                     if ([self respondsToSelector:@selector(successfullyReUploaded)]) {
                         [self performSelector:@selector(successfullyReUploaded)];
                     }
                     self.edited = FALSE;
                     [self performSelectorOnMainThread:@selector(save)
                                            withObject:nil
                                         waitUntilDone:TRUE];
                 } else {
                     //
                 }
             } else {
                 //
             }

             NSDictionary *dict = @{@"response": response, @"data":data};
             [controller performSelectorOnMainThread:completion
                                          withObject:dict
                                       waitUntilDone:NO];
         }
     }];

    [dataTask resume];
}

@end
