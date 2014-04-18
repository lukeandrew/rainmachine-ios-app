//
//  AppDelegate.h
//  Sprinklers
//
//  Created by Daniel Cristolovean on 1/16/13.
//  Copyright (c) 2013 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StatsVC;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, strong) StatsVC *statsVC;

- (void)refreshRootViews:(NSString*)unit;

@end
