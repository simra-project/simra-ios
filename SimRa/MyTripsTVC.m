//
//  MyTripsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "MyTripsTVC.h"
#import "AppDelegate.h"
#import "TripEditVC.h"
#import "NSTimeInterval+hms.h"

@interface MyTripsTVC ()
@property (strong, nonatomic) UIAlertController *ac;
@end

@implementation MyTripsTVC

NSInteger revertedSort(id num1, id num2, void *context) {
    NSNumber *n1 = (NSNumber *)num1;
    NSNumber *n2 = (NSNumber *)num2;
    return [n2 compare:n1];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem.enabled = FALSE;
    if (self.tableView.indexPathForSelectedRow) {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:FALSE];
    }
    [self.tableView reloadData];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return ad.trips.trips.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"trip" forIndexPath:indexPath];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSNumber *key = [ad.trips.trips.allKeys sortedArrayUsingFunction:revertedSort context:nil][indexPath.row];
    Trip *trip = ad.trips.trips[key];

    NSString *status;

    if (trip.edited) {
        status = NSLocalizedString(@"Edited", @"Edited");
    } else {
        if (trip.uploaded) {
            status = NSLocalizedString(@"Uploaded", @"Uploaded");
        } else {
            status = NSLocalizedString(@"New", @"New");
        }
    }

    NSDateFormatter *startFormatter = [[NSDateFormatter alloc] init];
    startFormatter.dateStyle = NSDateFormatterShortStyle;
    startFormatter.timeStyle =NSDateFormatterShortStyle;

    NSDateInterval *duration = trip.duration;
    NSTimeInterval seconds = [duration.endDate timeIntervalSinceDate:duration.startDate];

    cell.textLabel.text = [NSString stringWithFormat:@"%@",
                           status];

    cell.detailTextLabel.text = [NSString stringWithFormat:@" %@, %@, %.01f km",
                                 [startFormatter stringFromDate:trip.duration.startDate],
                                 hms(seconds),
                                 trip.length / 1000.0];
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSNumber *key = [ad.trips.trips.allKeys sortedArrayUsingFunction:revertedSort context:nil][indexPath.row];
    Trip *trip = ad.trips.trips[key];
    if (trip.uploaded) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.navigationItem.rightBarButtonItem.enabled = TRUE;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NSLocalizedString(@"Delete locally", @"Confirmation button for delete My Trips table row");
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSNumber *key = [ad.trips.trips.allKeys sortedArrayUsingFunction:revertedSort context:nil][indexPath.row];
        [ad.trips deleteTripWithIdentifier:key.integerValue];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"edit:"] &&
        [segue.destinationViewController isKindOfClass:[TripEditVC class]] &&
        [sender isKindOfClass:[UITableViewCell class]]) {
        TripEditVC *tripEditVC = (TripEditVC *)segue.destinationViewController;
        UITableViewCell *cell = (UITableViewCell *)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSNumber *key = [ad.trips.trips.allKeys sortedArrayUsingFunction:revertedSort context:nil][indexPath.row];
        Trip *trip = ad.trips.trips[key];
        tripEditVC.trip = trip;
        tripEditVC.changed = FALSE;
    }
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

- (IBAction)uploadPressed:(UIBarButtonItem *)sender {
    if (self.tableView.indexPathForSelectedRow) {
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSNumber *key = [ad.trips.trips.allKeys sortedArrayUsingFunction:revertedSort context:nil][self.tableView.indexPathForSelectedRow.row];
        Trip *trip = ad.trips.trips[key];

        [trip uploadFile:@"ride"
          WithController:self
                   error:@selector(completionError:)
              completion:@selector(completionResponse:)];

        self.ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
                                                      message:NSLocalizedString(@"Running", @"Running")
                                               preferredStyle:UIAlertControllerStyleAlert];

        [self presentViewController:self.ac animated:TRUE completion:nil];
    }
}

- (void)completionError:(NSError *)connectionError {
    [self.ac dismissViewControllerAnimated:TRUE completion:^(){
        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
                                 message:[NSString stringWithFormat:@"%@ %@",
                                          NSLocalizedString(@"UploadError", @"UploadError"),
                                          connectionError.localizedDescription]
                                 preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self.tableView reloadData];
                                                    }];
        [ac addAction:aay];
        [self presentViewController:ac animated:TRUE completion:nil];
    }];
}

- (void)completionResponse:(NSDictionary *)dict {
    NSURLResponse *response = dict[@"response"];
    NSData *data = dict[@"data"];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
            [self.ac dismissViewControllerAnimated:TRUE completion:^() {
                [self positiveCompletionResponse:httpResponse.statusCode
                                        withText:@""];
            }];
        } else {
            [self.ac dismissViewControllerAnimated:TRUE completion:^() {
                [self negativeCompletionResponse:httpResponse.statusCode
                                        withText:[[NSString alloc]
                                                  initWithData:data
                                                  encoding:NSUTF8StringEncoding]];
            }];
        }
    } else {
        [self.ac dismissViewControllerAnimated:TRUE completion:^() {
            [self noCompletionResponse];
        }];
    }
}

- (void)positiveCompletionResponse:(NSInteger)statusCode withText:(NSString *)text {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.trips uploadFile:@"profile"
          WithController:self
                   error:@selector(completionErrorTrips:)
              completion:@selector(completionResponseTrips:)];

    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:NSLocalizedString(@"Profile Running", @"Profile Running")
               preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:self.ac
                       animated:TRUE
                     completion:nil];
}

- (void)negativeCompletionResponse:(NSInteger)statusCode withText:(NSString *)text {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:[NSString stringWithFormat:@"%@\nHTTP:%ld %@",
                        NSLocalizedString(@"UploadError", @"UploadError"),
                        (long)statusCode,
                        text]
               preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
                                                    [self.tableView reloadData];
                                                }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

- (void)noCompletionResponse {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:[NSString stringWithFormat:@"%@ no HTTP response",
                        NSLocalizedString(@"UploadError", @"UploadError")]
               preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
                                                    [self.tableView reloadData];
                                                }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

- (void)completionErrorTrips:(NSError *)connectionError {
    [self.ac dismissViewControllerAnimated:TRUE completion:^(){
        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
                                 message:[NSString stringWithFormat:@"%@ %@",
                                          NSLocalizedString(@"Profile UploadError", @"Profile UploadError"),
                                          connectionError.localizedDescription]
                                 preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self.tableView reloadData];
                                                    }];
        [ac addAction:aay];
        [self presentViewController:ac animated:TRUE completion:nil];
    }];
}

- (void)completionResponseTrips:(NSDictionary *)dict {
    NSURLResponse *response = dict[@"response"];
    NSData *data = dict[@"data"];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
            [self.ac dismissViewControllerAnimated:TRUE completion:^() {
                [self positiveCompletionResponseTrips:httpResponse.statusCode
                                        withText:@""];
            }];
        } else {
            [self.ac dismissViewControllerAnimated:TRUE completion:^() {
                [self negativeCompletionResponseTrips:httpResponse.statusCode
                                        withText:[[NSString alloc]
                                                  initWithData:data
                                                  encoding:NSUTF8StringEncoding]];
            }];
        }
    } else {
        [self.ac dismissViewControllerAnimated:TRUE completion:^() {
            [self noCompletionResponseTrips];
        }];
    }
}

- (void)positiveCompletionResponseTrips:(NSInteger)statusCode withText:(NSString *)text {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:[NSString stringWithFormat:@"%@\nHTTP:%ld %@",
                        NSLocalizedString(@"Profile UploadSuccessfull", @"Profile UploadSuccessfull"),
                        (long)statusCode,
                        text]
               preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *aay = [UIAlertAction
                          actionWithTitle:NSLocalizedString(@"OK", @"OK")
                          style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * _Nonnull action) {
                              [self.tableView reloadData];
                          }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

- (void)negativeCompletionResponseTrips:(NSInteger)statusCode withText:(NSString *)text {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:[NSString stringWithFormat:@"%@\nHTTP:%ld %@",
                        NSLocalizedString(@"Profile UploadError", @"Profile UploadError"),
                        (long)statusCode,
                        text]
               preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
                                                    [self.tableView reloadData];
                                                }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

- (void)noCompletionResponseTrips {
    self.ac = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
               message:[NSString stringWithFormat:@"%@ no HTTP response",
                        NSLocalizedString(@"Profile UploadError", @"Profile UploadError")]
               preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
                                                    [self.tableView reloadData];
                                                }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

@end
