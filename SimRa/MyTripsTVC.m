//
//  MyTripsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "MyTripsTVC.h"
#import "AppDelegate.h"
#import "TripEditVC.h"
#import "NSTimeInterval+hms.h"

//#warning DEBUG SIMULATE_UNKNOWN_FILEHASH
//#define SIMULATE_UNKNOWN_FILEHASH @"12345678"
//#warning DEBUG EXTRA_OUTPUT
//#define EXTRA_OUTPUT 1

@interface MyTripsTVC ()
@property (strong, nonatomic) UIAlertController *ac;
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, TripInfo *> *localTripInfos;
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, TripInfo *> *uploadedTripInfos;
@end

@implementation MyTripsTVC

- (void)getTripInfos {
    self.localTripInfos = [[NSMutableDictionary alloc] init];
    self.uploadedTripInfos = [[NSMutableDictionary alloc] init];
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    for (TripInfo *tripInfo in ad.trips.tripInfos.allValues) {
        if (tripInfo.uploaded && !tripInfo.edited) {
            self.uploadedTripInfos[[NSNumber numberWithInteger:tripInfo.identifier]] = tripInfo;
        } else {
            self.localTripInfos[[NSNumber numberWithInteger:tripInfo.identifier]] = tripInfo;
        }
    }
}

- (TripInfo *)getTripInfo:(NSIndexPath *)indexPath {
    TripInfo *tripInfo;
    if (indexPath.section == 0) {
        NSNumber *key = [self.localTripInfos.allKeys sortedArrayUsingFunction:revertedSort
                                                                      context:nil][indexPath.row];
        tripInfo = self.localTripInfos[key];
    } else {
        NSNumber *key = [self.uploadedTripInfos.allKeys sortedArrayUsingFunction:revertedSort
                                                                         context:nil][indexPath.row];
        tripInfo = self.uploadedTripInfos[key];
    }
    return tripInfo;
}

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

    if (self.preselectedTrip) {
        [self performSegueWithIdentifier:@"edit:" sender:nil];
    } else {
        self.navigationItem.rightBarButtonItem.enabled = FALSE;
        if (self.tableView.indexPathForSelectedRow) {
            [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:FALSE];
        }
    }
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self adjustSelection];
}

- (void)adjustSelection {
    self.navigationItem.rightBarButtonItem.enabled = FALSE;

    if (self.tableView.indexPathForSelectedRow) {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:FALSE];
    }

    [self getTripInfos];

    if (self.localTripInfos.count > 0) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                    animated:FALSE
                              scrollPosition:UITableViewScrollPositionMiddle];
        self.navigationItem.rightBarButtonItem.enabled = TRUE;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self getTripInfos];
    if (section == 0) {
        return self.localTripInfos.count;
    } else {
        return self.uploadedTripInfos.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return self.localTripInfos.count > 0 ? NSLocalizedString(@"Not Uploaded", @"Not Uploaded") : nil;
    } else {
        return self.uploadedTripInfos.count > 0 ? NSLocalizedString(@"Uploaded", @"Uploaded") : nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"trip" forIndexPath:indexPath];
    TripInfo *tripInfo = [self getTripInfo:indexPath];

    NSString *status;

    if (tripInfo.edited) {
        status = NSLocalizedString(@"Edited", @"Edited");
        if (tripInfo.statisticsAdded) {
            status = [status stringByAppendingFormat:@"-%@",
                      NSLocalizedString(@"Completed", @"Completed")];
        }
    } else {
        if (tripInfo.uploaded) {
            status = NSLocalizedString(@"Uploaded", @"Uploaded");
        } else {
            status = NSLocalizedString(@"New", @"New");
            if (tripInfo.statisticsAdded) {
                status = [status stringByAppendingFormat:@"-%@",
                          NSLocalizedString(@"Completed", @"Completed")];
            }
        }
    }

    NSDateFormatter *startFormatter = [[NSDateFormatter alloc] init];
    startFormatter.dateStyle = NSDateFormatterShortStyle;
    startFormatter.timeStyle =NSDateFormatterShortStyle;

    NSDateInterval *duration = tripInfo.duration;
    NSTimeInterval seconds = [duration.endDate timeIntervalSinceDate:duration.startDate];

    cell.textLabel.text = [NSString stringWithFormat:@"%@",
                           status];

    NSString *detail = [NSString stringWithFormat:@" %@, %@, %.01f km",
                        [startFormatter stringFromDate:tripInfo.duration.startDate],
                        hms(seconds),
                        tripInfo.length / 1000.0];
#ifdef EXTRA_OUTPUT
    detail = [detail stringByAppendingFormat:@" (%ld/%ld/%d)",
              (long)tripInfo.validAnnotationsCount,
              (long)tripInfo.annotationsCount,
              tripInfo.reUploaded];
#endif

    cell.detailTextLabel.text = detail;
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return indexPath;
    } else {
        return nil;
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
        TripInfo *tripInfo = [self getTripInfo:indexPath];
        AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.trips deleteTripWithIdentifier:tripInfo.identifier];
        [tableView performBatchUpdates:^{
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        } completion:^(BOOL finished) {
            [self performSelector:@selector(adjustSelection) withObject:nil afterDelay:1.0];
        }];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){

    TripInfo *tripInfo = [self getTripInfo:indexPath];
    Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];

    UIImage *shareIcon = [UIImage systemImageNamed:@"square.and.arrow.up"];
    UIAction *exportAction = [UIAction actionWithTitle:NSLocalizedString(@"Manual Export", @"MyTrips View Context menu export title") image:shareIcon identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[trip csvFile]] applicationActivities:nil];
        [self presentViewController:activityController animated:true completion:nil];
    }];
    
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:NSLocalizedString(@"Actions", @"MyTrips View Context menu title") children:@[exportAction]];
    }];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"edit:"] &&
        [segue.destinationViewController isKindOfClass:[TripEditVC class]]) {
        TripEditVC *tripEditVC = (TripEditVC *)segue.destinationViewController;
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell *)sender;
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            TripInfo *tripInfo = [self getTripInfo:indexPath];
            Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];
            tripEditVC.trip = trip;
            tripEditVC.clean = TRUE;
            tripEditVC.changed = FALSE;
        } else {
            tripEditVC.trip = self.preselectedTrip;
            self.preselectedTrip = false;
            tripEditVC.changed = FALSE;
        }
    }
}

- (IBAction)uploadPressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if (!ad.regions.regionSelected) {
        NSString *message = [NSString stringWithFormat:@"%@ %@",
                             NSLocalizedString(@"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:",
                                                       @"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:"),
                             ad.regions.regionId == 0 ? ad.regions.currentRegion.identifier : ad.regions.currentRegion.localizedDescription];


        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Please choose a Region",
                                                                            @"Please choose a Region")
                                 message: message
                                 preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self performSegueWithIdentifier:@"profile" sender:nil];
                                                    }];
        [ac addAction:aay];
        [self presentViewController:ac animated:TRUE completion:nil];
    } else {
        if (self.tableView.indexPathForSelectedRow) {
            TripInfo *tripInfo = [self getTripInfo:self.tableView.indexPathForSelectedRow];
            Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];
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
                                                        [self adjustSelection];
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
                                                    [self adjustSelection];
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
                                                    [self adjustSelection];
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
                                                        [self adjustSelection];
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
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;

#if 0 // postponed implementation
    for (NSNumber *key in [ad.trips.tripInfos.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        TripInfo *tripInfo = ad.trips.tripInfos[key];
        NSLog(@"positiveCompletionResponseTrips %ld (%ld/%ld/%d)",
              tripInfo.identifier,
              tripInfo.validAnnotationsCount,
              tripInfo.annotationsCount,
              tripInfo.reUploaded);
        if (tripInfo.validAnnotationsCount == 0 && tripInfo.uploaded && !tripInfo.reUploaded) {
            Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];
#ifdef SIMULATE_UNKNOWN_FILEHASH
            trip.fileHash = SIMULATE_UNKNOWN_FILEHASH;
#endif
            [trip uploadFile:@"ride"
              WithController:self
                       error:@selector(completionErrorTrips:)
                  completion:@selector(completionResponseTrips:)];

            self.ac = [UIAlertController
                       alertControllerWithTitle:[NSString stringWithFormat:@"%@ %ld",
                                                 NSLocalizedString(@"Re-Upload", @"Re-Upload"),
                                                 tripInfo.identifier]
                       message:NSLocalizedString(@"Running", @"Running")
                       preferredStyle:UIAlertControllerStyleAlert];

            [self presentViewController:self.ac animated:TRUE completion:nil];
            return;
        }
    }
#endif // postponed implementation

    [self.tableView reloadData];
    [self adjustSelection];
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
                                                    [self adjustSelection];
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
                                                    [self adjustSelection];
                                                }];
    [self.ac addAction:aay];
    [self presentViewController:self.ac animated:TRUE completion:nil];
}

@end
