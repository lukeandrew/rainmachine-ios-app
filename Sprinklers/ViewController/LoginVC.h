//
//  LoginVC.h
//  Sprinklers
//
//  Created by Daniel Cristolovean on 17/12/13.
//  Copyright (c) 2013 Tremend. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Sprinkler.h"
#import "Protocols.h"

@class DevicesVC;

@interface LoginVC : UIViewController <UITextFieldDelegate, SprinklerResponseProtocol>

@property (strong, nonatomic) Sprinkler *sprinkler;
@property (weak, nonatomic) DevicesVC *parent;

@end
