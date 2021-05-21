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

// This is only necessary because the backend uses a self signed
// certificate currently
// If the certificate will be replaced by a certificate issued
// by a trusted CA (e.g. letsencrypt), the code marked with
// SELF_SIGNED_HACK can go and the entry in Info.plist may
// be deleted too:
// <key>NSAppTransportSecurity</key>
//      <dict>
//          <key>NSAllowsArbitraryLoads</key>
//          <true/>
//      </dict>
// and the file `server.cer` can be removed from the build

#define SELF_SIGNED_HACK 0

#define UPLOAD_SCHEME @"https:"
#if SELF_SIGNED_HACK
#define UPLOAD_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
//#define UPLOAD_HOST @"vm3.mcc.tu-berlin.de:8082"
#ifdef DEBUG
#define UPLOAD_HOST @"vm1.mcc.tu-berlin.de:8082"
#else
#define UPLOAD_HOST @"vm2.mcc.tu-berlin.de:8082"
#endif
#endif
#define UPLOAD_VERSION 10

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

- (void)uploadFile:(NSString *)name WithController:(id)controller error:(SEL)error completion:(SEL)completion {
    NSURL *csvFile = self.csvFile;

    NSData *data = [NSData dataWithContentsOfURL:csvFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"data:\n%@", string);

    AppDelegate *ad = [AppDelegate sharedDelegate];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString;
    if (self.fileHash && self.filePasswd) {
        urlString = [NSString stringWithFormat:@"%@//%@/%d/%@?fileHash=%@&filePassword=%@&loc=%@&clientHash=%@",
                     UPLOAD_SCHEME, UPLOAD_HOST, UPLOAD_VERSION,
                     name,
                     self.fileHash,
                     self.filePasswd,
                     ad.regions.currentRegion.identifier,
                     NSString.clientHash];
        [request setHTTPMethod:@"PUT"];
    } else {
        urlString = [NSString stringWithFormat: @"%@//%@/%d/%@?loc=%@&clientHash=%@",
                     UPLOAD_SCHEME, UPLOAD_HOST, UPLOAD_VERSION,
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
#if SELF_SIGNED_HACK
     [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:self delegateQueue:nil]
#else
     [NSURLSession sharedSession]
#endif
     uploadTaskWithRequest:request
     fromFile:csvFile
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *connectionError) {

         NSError *fmError;
         [[NSFileManager defaultManager] removeItemAtURL:csvFile error:&fmError];

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

#if SELF_SIGNED_HACK
- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
    NSData *remoteCertificateData = CFBridgingRelease(SecCertificateCopyData(certificate));
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"server" ofType:@"cer"];
    NSData *localCertData = [NSData dataWithContentsOfFile:cerPath];

    if ([remoteCertificateData isEqualToData:localCertData])
    {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }
    else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
    }
}
#endif

@end
