//
//  GraphDateBarDescriptor.h
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GraphTimeInterval;

@interface GraphDateBarDescriptor : NSObject

@property (nonatomic, assign) CGFloat dateBarHeight;
@property (nonatomic, assign) CGFloat weekdaysBarHeight;
@property (nonatomic, assign) CGFloat dateBarBottomPadding;
@property (nonatomic, strong) UIFont *timeIntervalFont;
@property (nonatomic, strong) UIColor *timeIntervalColor;
@property (nonatomic, strong) UIFont *dateValuesFont;
@property (nonatomic, strong) UIColor *dateValuesColor;
@property (nonatomic, strong) UIColor *dateValueSelectionColor;
@property (nonatomic, strong) NSArray *hasWeekdaysBar;

+ (GraphDateBarDescriptor*)defaultDescriptor;
- (CGFloat)totalBarHeightForGraphTimeInterval:(GraphTimeInterval*)graphTimeInterval;
- (BOOL)hasWeekdaysBarForGraphTimeInterval:(GraphTimeInterval*)graphTimeInterval;

@end
