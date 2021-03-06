//
//  GraphTimeInterval.h
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    GraphTimeIntervalType_Weekly,
    GraphTimeIntervalType_Monthly,
    GraphTimeIntervalType_Yearly
} GraphTimeIntervalType;

@class GraphDataSource;

@interface GraphTimeInterval : NSObject

@property (nonatomic, readonly) GraphTimeIntervalType type;
@property (nonatomic, readonly) NSString *name;

+ (GraphTimeInterval*)graphTimeIntervalWithType:(GraphTimeIntervalType)type;
+ (NSArray*)graphTimeIntervals;
+ (void)reloadRegisteredGraphTimeIntervals;

@property (nonatomic, strong) NSArray *graphTimeIntervalParts;
@property (nonatomic, readonly) NSInteger currentDateTimeIntervalPartIndex;

@end
