//
//  GraphTimeInterval.m
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GraphTimeInterval.h"
#import "GraphDataSource.h"
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

- (NSString*)timeIntervalValue {
    if (self.type == GraphTimeIntervalType_Weekly) return self.currentMonthString;
    if (self.type == GraphTimeIntervalType_Monthly) return self.currentMonthString;
    if (self.type == GraphTimeIntervalType_Yearly) return self.currentYearString;
    return nil;
}

- (NSArray*)dateValuesForCount:(NSInteger)count currentDateValueIndex:(NSInteger*)currentDateValueIndex {
    if (self.type == GraphTimeIntervalType_Weekly) return [self daysArrayInWeekCurrentDateValueIndex:currentDateValueIndex];
    if (self.type == GraphTimeIntervalType_Monthly) return [self daysArrayInMonthWithCount:count currentDateValueIndex:currentDateValueIndex];
    if (self.type == GraphTimeIntervalType_Yearly) return [self monthsArrayInYearWithCount:count currentDateValueIndex:currentDateValueIndex];
    return nil;
}

#pragma mark - Helper methods

- (NSString*)currentMonthString {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"MMM";
    return [[dateFormatter stringFromDate:[NSDate date]] lowercaseString];
}

- (NSString*)currentYearString {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yy";
    return [NSString stringWithFormat:@"'%@",[dateFormatter stringFromDate:[NSDate date]]];
}

- (NSArray*)monthsOfYear {
    return [NSArray arrayWithObjects:abbrevMonthsOfYear count:12];
}

- (NSArray*)daysArrayInWeekCurrentDateValueIndex:(NSInteger*)currentDateValueIndex {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitDay fromDate:date];
    NSRange daysRange = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:date];
    
    NSInteger firstDay = dateComponents.day - 3;
    NSInteger lastDay = dateComponents.day + 3;
    NSInteger currentDayIndex = 3;
    
    if (firstDay < 1) {
        currentDayIndex += (firstDay - 1);
        lastDay += (1 - firstDay);
        firstDay = 1;
    }
    
    if (lastDay > daysRange.length) {
        currentDayIndex += (lastDay - daysRange.length);
        firstDay -= (lastDay - daysRange.length);
        lastDay = daysRange.length;
    }
    
    NSMutableArray *daysArray = [NSMutableArray new];
    
    for (NSInteger index = firstDay; index <= lastDay; index++) {
        [daysArray addObject:[NSString stringWithFormat:@"%02d",(int)index]];
    }
    
    if (currentDateValueIndex) *currentDateValueIndex = currentDayIndex;
    
    return daysArray;
}

- (NSArray*)daysArrayInMonthWithCount:(NSInteger)count currentDateValueIndex:(NSInteger*)currentDateValueIndex {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitDay fromDate:date];
    NSRange daysRange = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:date];
    
    double intervalLength = (daysRange.length - 1) / (count - 1.0);
    double dayIndex = 0.0;
    double oldDayIndex = 0.0;
    
    NSInteger currentDayIndex = -1;
    NSMutableArray *daysArray = [NSMutableArray new];
    
    for (NSInteger index = 0; index < count; index++) {
        NSString *day = [NSString stringWithFormat:@"%02d",(int)(round(dayIndex) + 1)];
        [daysArray addObject:day];
        
        if (round(oldDayIndex) + 1 < dateComponents.day && dateComponents.day < round(dayIndex) + 1) {
            [daysArray removeLastObject];
            [daysArray addObject:[NSString stringWithFormat:@"%02d",(int)dateComponents.day]];
            currentDayIndex = index;
        } else if (round(dayIndex) + 1 == dateComponents.day) {
            currentDayIndex = index;
        }
        
        oldDayIndex = dayIndex;
        dayIndex += intervalLength;
    }
    
    if (currentDateValueIndex) *currentDateValueIndex = currentDayIndex;
    
    return daysArray;
}

- (NSArray*)monthsArrayInYearWithCount:(NSInteger)count currentDateValueIndex:(NSInteger*)currentDateValueIndex {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitMonth fromDate:date];
    
    NSArray *monthsOfYear = self.monthsOfYear;
    
    double intervalLength = (monthsOfYear.count - 1) / (count - 1.0);
    double monthIndex = 0.0;
    double oldMonthIndex = 0.0;
    
    NSInteger currentMonthIndex = -1;
    NSMutableArray *monthsArray = [NSMutableArray new];
    
    for (NSInteger index = 0; index < count; index++) {
        if (monthIndex > monthsOfYear.count - 1) monthIndex = monthsOfYear.count - 1;
        
        NSString *month = [[monthsOfYear objectAtIndex:(int)round(monthIndex)] lowercaseString];
        [monthsArray addObject:month];
        
        if (round(oldMonthIndex) + 1 < dateComponents.month && dateComponents.month < round(monthIndex) + 1) {
            [monthsArray removeLastObject];
            [monthsArray addObject:[[monthsOfYear objectAtIndex:dateComponents.month - 1] lowercaseString]];
            currentMonthIndex = index;
        } else if (round(monthIndex) + 1 == dateComponents.month) {
            currentMonthIndex = index;
        }
        
        oldMonthIndex = monthIndex;
        monthIndex += intervalLength;
    }
    
    if (*currentDateValueIndex) *currentDateValueIndex = currentMonthIndex;
    
    return monthsArray;
}

#pragma mark - Values and data sources

- (NSArray*)timeIntervalRestrictedValuesForGraphDataSource:(GraphDataSource*)dataSource {
    NSMutableArray *timeIntervalRestrictedValues = [NSMutableArray new];
    NSArray *dateStrings = self.allDateStringsInTimeInterval;
    
    for (NSArray *dateString in dateStrings) {
        id value = dataSource.values[dateString];
        if (value) [timeIntervalRestrictedValues addObject:value];
        else [timeIntervalRestrictedValues addObject:[NSNull null]];
    }
    
    return timeIntervalRestrictedValues;
}

- (NSArray*)timeIntervalRestrictedTopValuesForGraphDataSource:(GraphDataSource*)dataSource {
    NSMutableArray *timeIntervalRestrictedTopValues = [NSMutableArray new];
    NSArray *dateStrings = self.allDateStringsInTimeInterval;
    
    for (NSArray *dateString in dateStrings) {
        id value = dataSource.topValues[dateString];
        if (value) [timeIntervalRestrictedTopValues addObject:value];
        else [timeIntervalRestrictedTopValues addObject:[NSNull null]];
    }
    
    return timeIntervalRestrictedTopValues;
}

- (NSArray*)timeIntervalRestrictedIconImageIndexesForGraphDataSource:(GraphDataSource*)dataSource {
    NSMutableArray *timeIntervalRestrictedIconImageIndexes = [NSMutableArray new];
    NSArray *dateStrings = self.allDateStringsInTimeInterval;
    
    for (NSArray *dateString in dateStrings) {
        id iconImageIndex = dataSource.iconImageIndexes[dateString];
        if (iconImageIndex) [timeIntervalRestrictedIconImageIndexes addObject:iconImageIndex];
        else [timeIntervalRestrictedIconImageIndexes addObject:[NSNull null]];
    }
    
    return timeIntervalRestrictedIconImageIndexes;
}

- (NSArray*)allDateStringsInTimeInterval {
    if (self.type == GraphTimeIntervalType_Weekly) return self.allDateStringsInWeek;
    if (self.type == GraphTimeIntervalType_Monthly) return self.allDateStringsInMonth;
    if (self.type == GraphTimeIntervalType_Yearly) return self.allDateStringsInYear;
    return nil;
}

- (NSArray*)allDateStringsInWeek {
    NSMutableArray *allDateStringsInWeek = [NSMutableArray new];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    
    NSArray *daysArrayInWeek = [self daysArrayInWeekCurrentDateValueIndex:nil];
    
    for (NSNumber *dayValue in daysArrayInWeek) {
        NSString *dateString = [NSString stringWithFormat:@"%d-%02d-%02d", (int)dateComponents.year, (int)dateComponents.month, dayValue.intValue];
        [allDateStringsInWeek addObject:dateString];
    }
    
    return allDateStringsInWeek;
}

- (NSArray*)allDateStringsInMonth {
    NSMutableArray *allDateStringsInMonth = [NSMutableArray new];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    NSRange daysRange = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:date];
    
    for (NSInteger day = 1; day <= daysRange.length; day++) {
        NSString *dateString = [NSString stringWithFormat:@"%d-%02d-%02d", (int)dateComponents.year, (int)dateComponents.month, (int)day];
        [allDateStringsInMonth addObject:dateString];
    }
    
    return allDateStringsInMonth;
}

- (NSArray*)allDateStringsInYear {
    NSMutableArray *allDateStringsInYear = [NSMutableArray new];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [NSDate date];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear fromDate:date];
    
    for (NSInteger month = 0; month < 12; month++) {
        dateComponents.month = month + 1;
        NSRange monthRange = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:[calendar dateFromComponents:dateComponents]];
        
        for (NSInteger day = 0; day < monthRange.length; day++) {
            NSString *dateString = [NSString stringWithFormat:@"%d-%02d-%02d", (int)dateComponents.year, (int)month + 1, (int)day + 1];
            [allDateStringsInYear addObject:dateString];
        }
    }
    
    return allDateStringsInYear;
}

@end
