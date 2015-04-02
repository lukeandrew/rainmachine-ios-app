//
//  GraphDataFormatterProgramRuntime.m
//  Sprinklers
//
//  Created by Istvan Sipos on 07/02/15.
//  Copyright (c) 2015 Tremend. All rights reserved.
//

#import "GraphDataFormatterProgramRuntime.h"
#import "Constants.h"

@implementation GraphDataFormatterProgramRuntime

- (id)init {
    self = [super init];
    if (!self) return nil;
    
    GraphDataFormatter *formatter1 = [GraphDataFormatter new];
    formatter1.subFormatterIndex = 0;
    formatter1.descriptors = @[@{GraphDataFormatterDescriptorFieldType : @(GraphDataFormatterFieldTypeDateString),
                                 GraphDataFormatterDescriptorFieldKey : @"date",
                                 GraphDataFormatterDescriptorFieldAlignment : @(NSTextAlignmentCenter),
                                 GraphDataFormatterDescriptorFieldColor : [UIColor blackColor]}];
    
    GraphDataFormatter *formatter2 = [GraphDataFormatter new];
    formatter2.subFormatterIndex = 1;
    formatter2.descriptors = @[@{GraphDataFormatterDescriptorFieldType : @(GraphDataFormatterFieldTypeString),
                                 GraphDataFormatterDescriptorFieldValue : @"Program Runtime",
                                 GraphDataFormatterDescriptorFieldAlignment : @(NSTextAlignmentLeft),
                                 GraphDataFormatterDescriptorFieldColor : [UIColor blackColor]},
                               @{GraphDataFormatterDescriptorFieldType : @(GraphDataFormatterFieldTypePercetage),
                                 GraphDataFormatterDescriptorFieldKey : @"percentage",
                                 GraphDataFormatterDescriptorFieldAlignment : @(NSTextAlignmentRight),
                                 GraphDataFormatterDescriptorFieldColor : [UIColor darkGrayColor]}];
    
    self.subFormatters = @[formatter1, formatter2];
    
    return self;
}

@end
