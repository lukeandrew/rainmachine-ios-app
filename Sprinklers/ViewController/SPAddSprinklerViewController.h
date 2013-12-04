//
//  SPAddSprinklerViewController.h
//  Sprinklers
//
//  Created by Fabian Matyas on 03/12/13.
//  Copyright (c) 2013 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Sprinkler;

@interface SPAddSprinklerViewController : UITableViewController

@property (strong, nonatomic) Sprinkler *sprinkler;
- (IBAction)onSave:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *urlOrIPTextField;
@property (weak, nonatomic) IBOutlet UITextField *tokenEmailTextField;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@end
