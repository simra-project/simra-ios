//
//  IdPicker.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "IdPicker.h"

@interface IdPicker()
@property (strong, nonatomic) UIPickerView *pickerView;
@property (nonatomic) NSUInteger maxLines;

@end

@implementation IdPicker

- (void)initialize {
    self.pickerView = [[UIPickerView alloc] init];
    [self.pickerView setAutoresizingMask:
     UIViewAutoresizingFlexibleHeight |
     UIViewAutoresizingFlexibleWidth |
     UIViewAutoresizingFlexibleLeftMargin |
     UIViewAutoresizingFlexibleRightMargin];
    [self.pickerView setShowsSelectionIndicator:YES];
    self.pickerView.delegate = self;
    self.pickerView.dataSource = self;
    self.inputView = self.pickerView;

    UIBarButtonItem *doneButton =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
                                     style:UIBarButtonItemStyleDone
                                    target:self
                                    action:@selector(done:)];
    UIBarButtonItem *flexibleSpace =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                  target:nil
                                                  action:nil];
    UIToolbar *toolBar = [[UIToolbar alloc]initWithFrame:
                          CGRectMake(0, self.frame.size.height-50, 320, 50)];
    NSArray *toolbarItems = [NSArray arrayWithObjects:
                             flexibleSpace, doneButton, nil];
    [toolBar setItems:toolbarItems];
    self.inputAccessoryView = toolBar;
}

- (void)done:(UIBarButtonItem *)button {
    [self resignFirstResponder];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.array.count;
}

- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row
          forComponent:(NSInteger)component
           reusingView:(UIView *)view {
    UILabel *label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = self.array[row];
    return label;
}

- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    if (row >= 0 && row < self.array.count) {
        self.arrayIndex = row;
    } else {
        self.arrayIndex = 0;
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)setArrayIndex:(NSInteger)arrayIndex {
    if (arrayIndex < 0 || arrayIndex >= self.array.count) {
        arrayIndex = 0;
    }
    _arrayIndex = arrayIndex;
    [self.pickerView selectRow:arrayIndex inComponent:0 animated:TRUE];
    self.text = self.array[arrayIndex];
}

@end
