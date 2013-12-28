//
//  SPSprinklerListViewController.h
//  Sprinklers
//
//  Created by Fabian Matyas on 02/12/13.
//  Copyright (c) 2013 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@interface SprinklerListViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIView *viewLoading;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
