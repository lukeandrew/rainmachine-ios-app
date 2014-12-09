//
//  GraphDateBarDescriptor.h
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GraphDateBarDescriptor : NSObject

@property (nonatomic, assign) CGFloat dateBarHeight;
@property (nonatomic, strong) UIFont *timeIntervalFont;
@property (nonatomic, strong) UIColor *timeIntervalColor;
@property (nonatomic, strong) NSString *timeIntervalValue;
@property (nonatomic, strong) UIFont *dateValuesFont;
@property (nonatomic, strong) UIColor *dateValuesColor;
@property (nonatomic, strong) NSArray *dateValues;

+ (GraphDateBarDescriptor*)defaultDescriptor;

@end
