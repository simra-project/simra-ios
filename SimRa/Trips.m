//
//  Trips.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "Trips.h"
#import "AppDelegate.h"
#import "NSString+hashCode.h"

@implementation Trips
- (instancetype)init {
    self = [super init];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.version = [ad.defaults integerForKey:@"version"];
    self.uploaded = [ad.defaults boolForKey:@"uploaded"];
    self.fileHash = [ad.defaults stringForKey:@"fileHash"];
    self.filePasswd = [ad.defaults stringForKey:@"filePasswd"];

    self.trips = [[NSMutableDictionary alloc] init];
    NSLog(@"defaults %@", ad.defaults.dictionaryRepresentation);
    for (NSString *key in ad.defaults.dictionaryRepresentation.allKeys) {
        if ([key rangeOfString:@"Trip-"].location == 0) {
            NSDictionary *dict = [ad.defaults objectForKey:key];
            Trip *trip = [[Trip alloc] initFromDictionary:dict];
            [self.trips setObject:trip forKey:[NSNumber numberWithInteger:trip.identifier]];
        }
    }
    return self;
}

- (Trip *)newTrip {
    Trip *trip = [[Trip alloc] init];
    [self.trips setObject:trip forKey:[NSNumber numberWithInteger:trip.identifier]];
    return trip;
}

- (void)deleteTripWithIdentifier:(NSInteger)identifier {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults removeObjectForKey:[NSString stringWithFormat:@"Trip-%ld", identifier]];
    [self.trips removeObjectForKey:[NSNumber numberWithInteger:identifier]];
}

- (NSURL *)csvFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *temporaryDirectory = fm.temporaryDirectory;
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:@"trips.csv"];
    [fm createFileAtPath:fileURL.path
                contents:[[NSData alloc] init]
              attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:fileURL.path];
    
    NSString *csvString;
    
    csvString = [NSString stringWithFormat:@"i%@#%ld\n",
                 [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                 self.version];
    csvString = [csvString stringByAppendingString:@"birth,gender,region,experience,numberOfRides,duration,numberOfIncidents,length,idle"];
    for (NSInteger i = 0; i < 24; i++) {
        csvString = [csvString stringByAppendingFormat:@",%ld", i];
    }
    csvString = [csvString stringByAppendingString:@"\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    csvString = [NSString stringWithFormat:@"%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld",
                 [ad.defaults integerForKey:@"ageId"],
                 [ad.defaults integerForKey:@"sexId"],
                 [ad.defaults integerForKey:@"regionId"],
                 [ad.defaults integerForKey:@"experienceId"],
                 [ad.defaults integerForKey:@"totalRides"],
                 [ad.defaults integerForKey:@"totalDuration"],
                 [ad.defaults integerForKey:@"totalIncidents"],
                 [ad.defaults integerForKey:@"totalLength"],
                 [ad.defaults integerForKey:@"totalIdle"]];
    NSArray <NSNumber *> *totalSlots = [ad.defaults arrayForKey:@"totalSlots"];
    for (NSInteger i = 0; i < 24; i++) {
        csvString = [csvString stringByAppendingFormat:@",%ld",
                     totalSlots[i].integerValue];
    }
    csvString = [csvString stringByAppendingString:@"\n"];
    [fh writeData:[csvString dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
    return fileURL;
}

- (void)uploadWithController:(id)controller error:(SEL)error completion:(SEL)completion {
    NSURL *csvFile = self.csvFile;
    
    NSData *data = [NSData dataWithContentsOfURL:csvFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"data:\n%@", string);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSArray <NSString *> *locales = [ad.constants mutableArrayValueForKey:@"locales"];
    NSInteger regionId = [ad.defaults integerForKey:@"regionId"];
    
    NSString *urlString = [NSString stringWithFormat: @"https://vm1.mcc.tu-berlin.de:8082/9/upload?fileName=%@&loc=%@&clientHash=%@",
                           @"2",
                           locales[regionId],
                           NSString.clientHash];
    
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    
    [request setValue:@"text/plain" forHTTPHeaderField: @"Content-Type"];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask *dataTask =
    [
#if 1
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
         self.uploaded = TRUE;
         self.fileHash = @"HASH";
         self.filePasswd = @"Passwd";
         
         if (connectionError) {
             NSLog(@"connectionError %@", connectionError);
             [controller performSelectorOnMainThread:error
                                          withObject:connectionError
                                       waitUntilDone:NO];
         } else {
             NSLog(@"response %@ %@",
                   response,
                   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
             NSDictionary *dict = @{@"response": response, @"data":data};
             [controller performSelectorOnMainThread:completion
                                          withObject:dict
                                       waitUntilDone:NO];
         }
     }];
    
    [dataTask resume];
    self.version++;
    [self save];
}

- (void)save {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.defaults setInteger:self.version forKey:@"version"];
    [ad.defaults setBool:self.uploaded forKey:@"uploaded"];
    [ad.defaults setObject:self.fileHash forKey:@"fileHash"];
    [ad.defaults setObject:self.filePasswd forKey:@"filePasswd"];
}

- (void)addTripToStatistics:(Trip *)trip {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

    NSInteger totalRides = [ad.defaults integerForKey:@"totalRides"];
    NSInteger totalDuration = [ad.defaults integerForKey:@"totalDuration"];
    NSInteger totalIncidents = [ad.defaults integerForKey:@"totalIncidents"];
    NSInteger totalLength = [ad.defaults integerForKey:@"totalLength"];
    NSInteger totalIdle = [ad.defaults integerForKey:@"totalIdle"];
    NSMutableArray <NSNumber *> *totalSlots = [[ad.defaults arrayForKey:@"totalSlots"] mutableCopy];
    if (!totalSlots) {
        totalSlots = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < 24; i++) {
            [totalSlots setObject:[NSNumber numberWithInteger:0] atIndexedSubscript:i];
        }
    }

    totalRides++;
    totalDuration += [trip.duration.endDate timeIntervalSinceDate:trip.duration.startDate] * 1000.0;
    totalIncidents += trip.tripAnnotations;
    totalLength += trip.length;
    totalIdle += trip.idle;

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger hour;
    hour = [calendar component:NSCalendarUnitHour fromDate:trip.duration.startDate];
    [totalSlots setObject:[NSNumber numberWithInteger:totalSlots[hour].integerValue + 1] atIndexedSubscript:hour];
    hour = [calendar component:NSCalendarUnitHour fromDate:trip.duration.endDate];
    [totalSlots setObject:[NSNumber numberWithInteger:totalSlots[hour].integerValue + 1] atIndexedSubscript:hour];

    [ad.defaults setInteger:totalRides forKey:@"totalRides"];
    [ad.defaults setInteger:totalDuration forKey:@"totalDuration"];
    [ad.defaults setInteger:totalIncidents forKey:@"totalIncidents"];
    [ad.defaults setInteger:totalLength forKey:@"totalLength"];
    [ad.defaults setInteger:totalIdle forKey:@"totalIdle"];
    [ad.defaults setObject:totalSlots forKey:@"totalSlots"];
}

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

@end
