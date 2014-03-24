//
//  BaseVC.m
//  Sprinklers
//
//  Created by Fabian Matyas on 24/03/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "BaseVC.h"
#import "StorageManager.h"
#import "Constants.h"
#import "AppDelegate.h"

@implementation BaseVC

#pragma mark - Error handling

- (void)handleServerLoggedOutUser {
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    [StorageManager current].currentSprinkler.loginRememberMe = [NSNumber numberWithBool:NO];
    [[StorageManager current] saveData];
}

- (void)handleSprinklerError:(NSString *)errorMessage title:(NSString*)titleMessage showErrorMessage:(BOOL)showErrorMessage{
    //    [StorageManager current].currentSprinkler.lastError = errorMessage;
    //    [[StorageManager current] saveData];
    
    if ((errorMessage) && (showErrorMessage)) {
        self.alertView = [[UIAlertView alloc] initWithTitle:titleMessage message:errorMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        self.alertView.tag = kError_AlertViewTag;
        [self.alertView show];
    }
}

- (void)handleSprinklerGeneralError:(NSString *)errorMessage showErrorMessage:(BOOL)showErrorMessage {
    [self handleSprinklerError:errorMessage title:@"Sprinkler error" showErrorMessage:showErrorMessage];
}

- (void)handleSprinklerNetworkError:(NSString *)errorMessage showErrorMessage:(BOOL)showErrorMessage {
    [self handleSprinklerError:errorMessage title:@"Network error" showErrorMessage:showErrorMessage];
}

- (void)handleLoggedOutSprinklerError {
    NSString *errorTitle = @"Logged out";
    //    [StorageManager current].currentSprinkler.lastError = errorTitle;
    //    [[StorageManager current] saveData];
    
    self.alertView = [[UIAlertView alloc] initWithTitle:errorTitle message:@"You've been logged out by the server" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    self.alertView.tag = kLoggedOut_AlertViewTag;
    [self.alertView show];
}

#pragma mark - Alert view

- (void)alertView:(UIAlertView *)theAlertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (theAlertView.tag == kLoggedOut_AlertViewTag) {
        [self handleServerLoggedOutUser];
        
        [StorageManager current].currentSprinkler = nil;
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate refreshRootViews];
    }
    
    self.alertView = nil;
}

@end
