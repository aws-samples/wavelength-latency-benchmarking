// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NetperfWrapper: UIViewController<UITextFieldDelegate, CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *address, *address2;

@property (weak, nonatomic) IBOutlet UILabel *l_latency, *l_transactions, *l_latency2, *l_transactions2;

@property (weak, nonatomic) IBOutlet UIButton *b_start, *b_setup, *b_setup2;

@property (weak, nonatomic) IBOutlet UITextView *text;
@property (weak, nonatomic) IBOutlet UISwitch *s_cont;

@property (weak, nonatomic) IBOutlet UILabel *l_copied;

- (IBAction)setup_pressed:(id)sender;
- (IBAction)start_pressed:(id)sender;

@end

NS_ASSUME_NONNULL_END
