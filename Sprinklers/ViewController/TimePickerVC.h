//
//  TimePickerVC.h
//  Sprinklers
//
//  Created by Fabian Matyas on 26/02/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Protocols.h"
#import "BaseLevel2ViewController.h"

@interface TimePickerVC : BaseLevel2ViewController

@property (assign) int timeFormat;
@property (weak, nonatomic) id<TimePickerDelegate> parent;
@property (strong, nonatomic) NSDate *time;
@property (weak, nonatomic) IBOutlet UIPickerView *datePicker;

- (int)hour24Format;
- (int)minutes;
- (void)refreshUIWithHour:(int)h minutes:(int)m;

@end