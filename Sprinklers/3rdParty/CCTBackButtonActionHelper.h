//
//  CCTBackButtonActionHelper.h
//  BackButtonAction
//
//  Created by Weipin Xia on 5/13/13.
//  Copyright (c) 2013 Weipin Xia. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CCTBackButtonActionHelperProtocol <NSObject>

- (BOOL)cct_navigationBar:(UINavigationBar *)navigationBar willPopItem:(UINavigationItem *)item;

@end


@interface UINavigationController ()

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;

@end


@interface CCTBackButtonActionHelper : NSObject

@property (weak, nonatomic) UIViewController<CCTBackButtonActionHelperProtocol> *delegate;

+ (CCTBackButtonActionHelper*)sharedInstance;
- (BOOL)navigationController:(UINavigationController *)navigationController
               navigationBar:(UINavigationBar *)navigationBar
               shouldPopItem:(UINavigationItem *)item;

@end
