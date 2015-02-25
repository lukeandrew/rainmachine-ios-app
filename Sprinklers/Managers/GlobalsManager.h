//
//  GlobalsManager.h
//  Sprinklers
//
//  Created by Fabian Matyas on 25/02/15.
//  Copyright (c) 2015 Tremend. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Provision.h"
#import "Protocols.h"

@interface GlobalsManager : NSObject<SprinklerResponseProtocol>

@property (strong, nonatomic) Provision *provision;

+ (GlobalsManager*)current;

- (void)refresh;

@end
