//
//  ProvisionWiFiVC.h
//  Sprinklers
//
//  Created by Fabian Matyas on 01/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvailableWiFisVC.h"

@interface ProvisionWiFiVC : UITableViewController<UITextFieldDelegate>

@property (nonatomic, strong) NSString *securityOption;
@property (nonatomic, weak) AvailableWiFisVC *delegate;
@property (nonatomic, assign) BOOL showSSID;

@end
