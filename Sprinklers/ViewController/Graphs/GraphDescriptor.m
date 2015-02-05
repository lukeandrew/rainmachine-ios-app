//
//  GraphDescriptor.m
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GraphDescriptor.h"
#import "GraphTimeInterval.h"
#import "GraphVisualAppearanceDescriptor.h"
#import "GraphTitleAreaDescriptor.h"
#import "GraphIconsBarDescriptor.h"
#import "GraphValuesBarDescriptor.h"
#import "GraphDisplayAreaDescriptor.h"
#import "GraphDateBarDescriptor.h"
#import "GraphDataSource.h"
#import "GraphsManager.h"

#pragma mark -

@implementation GraphDescriptor {
    GraphTimeInterval *_graphTimeInterval;
}

+ (GraphDescriptor*)defaultDescriptor {
    GraphDescriptor *descriptor = [GraphDescriptor new];
    
    descriptor.dataSource = [GraphDataSource defaultDataSource];
    descriptor.visualAppearanceDescriptor = [GraphVisualAppearanceDescriptor defaultDescriptor];
    descriptor.titleAreaDescriptor = [GraphTitleAreaDescriptor defaultDescriptor];
    descriptor.displayAreaDescriptor = [GraphDisplayAreaDescriptor defaultDescriptor];
    descriptor.dateBarDescriptor = [GraphDateBarDescriptor defaultDescriptor];
    descriptor.graphTimeInterval = [GraphTimeInterval graphTimeIntervalWithType:GraphTimeIntervalType_Weekly];
    
    return descriptor;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[GraphDescriptor class]]) return NO;
    return [self.graphIdentifier isEqualToString:((GraphDescriptor*)object).graphIdentifier];
}

- (CGFloat)totalGraphHeight {
    GraphIconsBarDescriptor *iconsBarDescriptor = (self.graphTimeInterval ? self.iconsBarDescriptorsDictionary[@(self.graphTimeInterval.type)] : nil);
    GraphValuesBarDescriptor *valuesBarDescriptor = (self.graphTimeInterval ? self.valuesBarDescriptorsDictionary[@(self.graphTimeInterval.type)] : nil);
    
    return self.titleAreaDescriptor.titleAreaHeight +
        iconsBarDescriptor.iconsBarHeight +
        valuesBarDescriptor.valuesBarHeight +
        self.displayAreaDescriptor.displayAreaHeight +
        self.dateBarDescriptor.dateBarHeight + 6.0;
}

@end
