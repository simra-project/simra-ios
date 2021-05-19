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
@property (weak, nonatomic) IBOutlet UIBarButtonItem *uploadButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (strong, nonatomic) UIBarButtonItem *editButton;
@property (strong, nonatomic) UIBarButtonItem *doneButton;
@property (strong, nonatomic) UIBarButtonItem *allButton;
@property (strong, nonatomic) UIBarButtonItem *noneButton;
@end

@implementation MyTripsTVC

- (void)getTripInfos {
    self.localTripInfos = [[NSMutableDictionary alloc] init];
    self.uploadedTripInfos = [[NSMutableDictionary alloc] init];
    AppDelegate *ad = [AppDelegate sharedDelegate];
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

    self.editButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                       target:self
                       action:@selector(editToggle:)];
    self.doneButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                       target:self
                       action:@selector(editToggle:)];
    self.allButton = [[UIBarButtonItem alloc]
                      initWithTitle:NSLocalizedString(@"All", @"Table Select All")
                      style:UIBarButtonItemStylePlain
                      target:self
                      action:@selector(selectAll:)];
    self.noneButton = [[UIBarButtonItem alloc]
                       initWithTitle:NSLocalizedString(@"None", @"Table Select None")
                       style:UIBarButtonItemStylePlain
                       target:self
                       action:@selector(selectNone:)];

    NSMutableArray<UIBarButtonItem *> *r = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!r) {
        r = [[NSMutableArray alloc] init];
    }
    [r addObject:self.editButton];
    [self.navigationItem setRightBarButtonItems:r animated:TRUE];
}

- (IBAction)selectAll:(id)sender {
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    } else {
        [l removeLastObject];
    }
    [l addObject:self.noneButton];
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    for (NSInteger i = 0; i < self.localTripInfos.count; i++) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:FALSE scrollPosition:UITableViewScrollPositionNone];
    }
    for (NSInteger i = 0; i < self.uploadedTripInfos.count; i++) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:FALSE scrollPosition:UITableViewScrollPositionNone];
    }
    [self setUIElements];
}

- (IBAction)selectNone:(id)sender {
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    } else {
        [l removeLastObject];
    }
    [l addObject:self.allButton];
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    for (NSInteger i = 0; i < self.localTripInfos.count; i++) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:FALSE];
    }
    for (NSInteger i = 0; i < self.uploadedTripInfos.count; i++) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:FALSE];
    }
    [self setUIElements];
}

- (IBAction)editToggle:(id)sender {
    [self.tableView setEditing:!self.tableView.editing animated:TRUE];
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    }
    NSMutableArray<UIBarButtonItem *> *r = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!r) {
        r = [[NSMutableArray alloc] init];
    } else {
        [r removeLastObject];
    }
    if (self.tableView.editing) {
        [r addObject:self.doneButton];
        [l addObject:self.allButton];
        [self.navigationController setToolbarHidden:FALSE];
        [self setUIElements];
    } else {
        [r addObject:self.editButton];
        if (l.count > 0) {
            [l removeLastObject];
        }
        [self.navigationController setToolbarHidden:TRUE];
    }
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    [self.navigationItem setRightBarButtonItems:r animated:TRUE];
}
- (IBAction)uploadPressed:(UIBarButtonItem *)sender {
    if ([self checkRegion]) {
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            if (indexPath.section == 0) {
                [self doUpload:indexPath];
            }
        }
    }
}

- (IBAction)deletePressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        TripInfo *tripInfo = [self getTripInfo:indexPath];
        [ad.trips deleteTripWithIdentifier:tripInfo.identifier];
    }
    [self.tableView performBatchUpdates:^{
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    } completion:^(BOOL finished) {
        [self getTripInfos];
        [self setUIElements];
    }];
}

- (void)setUIElements {
    if (self.tableView.indexPathsForSelectedRows.count > 0) {
        self.uploadButton.enabled = TRUE;
        self.deleteButton.enabled = TRUE;
    } else {
        self.uploadButton.enabled = FALSE;
        self.deleteButton.enabled = FALSE;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.preselectedTrip) {
        [self performSegueWithIdentifier:@"editTrip:" sender:nil];
    }
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
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
//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    return YES;
//}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > 0) {
        return nil;
    }
    UIContextualAction *uploadAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"Upload", @"Upload Context")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ([self checkRegion]) {
            [self doUpload:indexPath];
        }
    }];
    uploadAction.backgroundColor = [UIColor systemBlueColor];
    UISwipeActionsConfiguration *sac = [UISwipeActionsConfiguration configurationWithActions:@[uploadAction]];
    sac.performsFirstActionWithFullSwipe = TRUE;
    return sac;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"Delete locally", @"Confirmation button for delete My Trips table row")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        TripInfo *tripInfo = [self getTripInfo:indexPath];
        AppDelegate *ad = [AppDelegate sharedDelegate];
        [ad.trips deleteTripWithIdentifier:tripInfo.identifier];
        [tableView performBatchUpdates:^{
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        } completion:^(BOOL finished) {
            [self getTripInfos];
        }];
    }];
    UISwipeActionsConfiguration *sac = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    sac.performsFirstActionWithFullSwipe = TRUE;
    return sac;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!tableView.editing) {
        [self performSegueWithIdentifier:@"editTrip:" sender:[tableView cellForRowAtIndexPath:indexPath]];
    } else {
        [self setUIElements];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self setUIElements];
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
    if ([segue.identifier isEqualToString:@"editTrip:"] &&
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

- (BOOL)checkRegion {
    AppDelegate *ad = [AppDelegate sharedDelegate];
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
        return FALSE;
    }
    return TRUE;
}

- (void)doUpload:(NSIndexPath *)indexPath {
    TripInfo *tripInfo = [self getTripInfo:indexPath];
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
    AppDelegate *ad = [AppDelegate sharedDelegate];
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
#if 0 // postponed implementation
    AppDelegate *ad = [AppDelegate sharedDelegate];

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
