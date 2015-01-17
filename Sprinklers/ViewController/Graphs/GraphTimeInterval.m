//
//  GraphTimeInterval.m
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GraphTimeInterval.h"
#import "GraphTimeIntervalPart.h"
#import "GraphDataSource.h"
#import "GraphsManager.h"
#import "Additions.h"
#import "Constants.h"

#pragma mark -

@interface GraphTimeInterval ()

@property (nonatomic, assign) GraphTimeIntervalType type;
@property (nonatomic, strong) NSString *name;

+ (void)registerGraphTimeIntervalWithType:(GraphTimeIntervalType)type name:(NSString*)name;

@property (nonatomic, readonly) NSString *currentMonthString;
@property (nonatomic, readonly) NSString *currentYearString;
@property (nonatomic, readonly) NSArray *monthsOfYear;

- (NSArray*)daysArrayInWeekCurrentDateValueIndex:(NSInteger*)currentDateValueIndex;
- (NSArray*)daysArrayInMonthWithCount:(NSInteger)count currentDateValueIndex:(NSInteger*)currentDateValueIndex;
- (NSArray*)monthsArrayInYearWithCount:(NSInteger)count currentDateValueIndex:(NSInteger*)currentDateValueIndex;

@property (nonatomic, readonly) NSArray *allDateStringsInTimeInterval;
@property (nonatomic, readonly) NSArray *allDateStringsInWeek;
@property (nonatomic, readonly) NSArray *allDateStringsInMonth;
@property (nonatomic, readonly) NSArray *allDateStringsInYear;

- (void)createGraphTimeIntervalPartsArray;
- (void)createWeeklyGraphTimeIntervalParts;
- (void)createMonthlyGraphTimeIntervalParts;
- (void)createYearlyGraphTimeIntervalParts;

@end

#pragma mark -

@implementation GraphTimeInterval

static NSMutableDictionary *registeredTimeIntervalsDictionary = nil;
static NSMutableArray *registeredTimeIntervals = nil;

+ (void)registerGraphTimeIntervalWithType:(GraphTimeIntervalType)type name:(NSString*)name {
    if (!registeredTimeIntervalsDictionary) registeredTimeIntervalsDictionary = [NSMutableDictionary new];
    if (!registeredTimeIntervals) registeredTimeIntervals = [NSMutableArray new];
    
    if ([registeredTimeIntervalsDictionary objectForKey:@(type)]) return;
    
    GraphTimeInterval *graphTimeInterval = [GraphTimeInterval new];
    graphTimeInterval.type = type;
    graphTimeInterval.name = name;
    
    [graphTimeInterval createGraphTimeIntervalPartsArray];
    
    [registeredTimeIntervalsDictionary setObject:graphTimeInterval forKey:@(type)];
    [registeredTimeIntervals addObject:graphTimeInterval];
}

+ (void)initialize {
    [self registerGraphTimeIntervalWithType:GraphTimeIntervalType_Weekly name:@"Week"];
    [self registerGraphTimeIntervalWithType:GraphTimeIntervalType_Monthly name:@"Month"];
    [self registerGraphTimeIntervalWithType:GraphTimeIntervalType_Yearly name:@"Year"];
}

+ (GraphTimeInterval*)graphTimeIntervalWithType:(GraphTimeIntervalType)type {
    return [registeredTimeIntervalsDictionary objectForKey:@(type)];
}

+ (NSArray*)graphTimeIntervals {
    return registeredTimeIntervals;
}

#pragma mark - Graph time interval parts

- (void)createGraphTimeIntervalPartsArray {
    if (self.type == GraphTimeIntervalType_Weekly) [self createWeeklyGraphTimeIntervalParts];
    else if (self.type == GraphTimeIntervalType_Monthly) [self createMonthlyGraphTimeIntervalParts];
    else if (self.type == GraphTimeIntervalType_Yearly) [self createYearlyGraphTimeIntervalParts];
}

- (void)createWeeklyGraphTimeIntervalParts {
    NSMutableArray *graphTimeIntervalParts = [NSMutableArray new];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.firstWeekday = 2;
    
    NSInteger totalDays = 0;
    NSDate *startDate = [GraphsManager sharedGraphsManager].startDate;
    
    NSDateComponents *startDateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitWeekday | NSCalendarUnitWeekOfYear fromDate:startDate];
    NSInteger startWeekDay = startDateComponents.weekday;
    
    startDateComponents.weekday = 2;
    startDate = [calendar dateFromComponents:startDateComponents];
    
    while (totalDays < [GraphsManager sharedGraphsManager].totalDays + startWeekDay - 1) {
        GraphTimeIntervalPart *graphTimeIntervalPart = [GraphTimeIntervalPart new];
        graphTimeIntervalPart.startDate = startDate;
        graphTimeIntervalPart.endDate = [startDate dateByAddingDays:6];
        graphTimeIntervalPart.length = 7;
        graphTimeIntervalPart.type = GraphTimeIntervalPartType_DisplayDays;

        [graphTimeIntervalPart initialize];
        [graphTimeIntervalParts addObject:graphTimeIntervalPart];
        
        totalDays += graphTimeIntervalPart.length;
        startDate = [startDate dateByAddingDays:graphTimeIntervalPart.length];
    }
    
    self.graphTimeIntervalParts = graphTimeIntervalParts;
}

- (void)createMonthlyGraphTimeIntervalParts {
    NSMutableArray *graphTimeIntervalParts = [NSMutableArray new];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSInteger totalDays = 0;
    NSDate *startDate = [GraphsManager sharedGraphsManager].startDate;
    
    NSDateComponents *startDateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:startDate];
    NSInteger startDay = startDateComponents.day;
    
    startDateComponents.day = 1;
    startDate = [calendar dateFromComponents:startDateComponents];
    
    while (totalDays < [GraphsManager sharedGraphsManager].totalDays + startDay - 1) {
        NSRange monthRange = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:startDate];
        
        GraphTimeIntervalPart *graphTimeIntervalPart = [GraphTimeIntervalPart new];
        graphTimeIntervalPart.startDate = startDate;
        graphTimeIntervalPart.endDate = [startDate dateByAddingDays:monthRange.length];
        graphTimeIntervalPart.length = monthRange.length;
        graphTimeIntervalPart.type = GraphTimeIntervalPartType_DisplayDays;
        
        [graphTimeIntervalPart initialize];
        [graphTimeIntervalParts addObject:graphTimeIntervalPart];
        
        totalDays += graphTimeIntervalPart.length;
        startDate = [startDate dateByAddingDays:graphTimeIntervalPart.length];
    }
    
    self.graphTimeIntervalParts = graphTimeIntervalParts;
}

- (void)createYearlyGraphTimeIntervalParts {
    GraphTimeIntervalPart *graphTimeIntervalPart = [GraphTimeIntervalPart new];
    graphTimeIntervalPart.startDate = [GraphsManager sharedGraphsManager].startDate;
    graphTimeIntervalPart.endDate = [[GraphsManager sharedGraphsManager].startDate dateByAddingDays:[GraphsManager sharedGraphsManager].totalDays];
    graphTimeIntervalPart.length = [GraphsManager sharedGraphsManager].totalDays;
    graphTimeIntervalPart.type = GraphTimeIntervalPartType_DisplayMonths;
    
    [graphTimeIntervalPart initialize];
    
    self.graphTimeIntervalParts = @[graphTimeIntervalPart];
}

@end
