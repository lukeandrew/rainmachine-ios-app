//
//  GraphsManager.h
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GraphDescriptor.h"

@interface GraphsManager : NSObject

@property (nonatomic, readonly) NSArray *availableGraphs;
@property (nonatomic, readonly) NSArray *selectedGraphs;

+ (GraphsManager*)sharedGraphsManager;
- (void)selectGraph:(GraphDescriptor*)graph;
- (void)deselectGraph:(GraphDescriptor*)graph;
- (void)selectAllGraphs;

- (void)moveGraphFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;
- (void)replaceGraphAtIndex:(NSInteger)index withGraph:(GraphDescriptor*)graph;

+ (void)setRandomizeTestData:(BOOL)randomizeTestData;
+ (BOOL)randomizeTestData;

@end

#pragma mark

@interface EmptyGraphDescriptor : GraphDescriptor

+ (EmptyGraphDescriptor*)emptyGraphDescriptorWithTotalGraphHeight:(CGFloat)totalGraphHeight;

@end

