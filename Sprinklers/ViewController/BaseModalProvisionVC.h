//
//  BaseModalProvision.h
//  Sprinklers
//
//  Created by Fabian Matyas on 14/02/15.
//  Copyright (c) 2015 Tremend. All rights reserved.
//

#import "BaseNetworkHandlingVC.h"

@interface BaseModalProvisionVC : BaseNetworkHandlingVC

@property (strong, nonatomic) UIViewController *delegate;
@property (strong, nonatomic) UIAlertView *alertView;
@property (assign, nonatomic) BOOL forceQuit;

- (void)setWizardNavBarForVC:(UIViewController*)viewController;
- (void)onCancel:(id)notif;
- (void)alertView:(UIAlertView *)theAlertView didDismissWithButtonIndex:(NSInteger)buttonIndex;

@end
