//
//  GraphsManager.m
//  Sprinklers
//
//  Created by Istvan Sipos on 09/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GraphsManager.h"
#import "GraphDescriptor.h"
#import "GraphTitleAreaDescriptor.h"
#import "GraphIconsBarDescriptor.h"
#import "GraphValuesBarDescriptor.h"
#import "GraphDisplayAreaDescriptor.h"
#import "GraphStyle.h"
#import "GraphStyleBars.h"
#import "GraphStyleLines.h"

NSString *kWaterConsumeGraphIdentifier              = @"WaterConsumeGraphIdentifier";
NSString *kTemperatureGraphIdentifier               = @"TemperatureGraphIdentifier";
NSString *kTotalProgramRuntimesGraphIdentifier      = @"TotalProgramRuntimesGraphIdentifier";

NSString *kEmptyGraphIdentifier                     = @"EmptyGraphIdentifier";

#pragma mark -

@interface GraphsManager ()

@property (nonatomic, strong) NSDictionary *availableGraphsDictionary;
@property (nonatomic, strong) NSArray *availableGraphs;
@property (nonatomic, strong) NSMutableArray *selectedGraphs;

- (void)registerAvailableGraphs;

@end

#pragma mark -

@implementation GraphsManager

static GraphsManager *sharedGraphsManager = nil;

+ (GraphsManager*)sharedGraphsManager {
    if (!sharedGraphsManager) sharedGraphsManager = [GraphsManager new];
    return sharedGraphsManager;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    
    [self registerAvailableGraphs];
    
    return self;
}

- (void)registerAvailableGraphs {
    NSMutableArray *availableGraphs = [NSMutableArray new];
    NSMutableDictionary *availableGraphsDictionary = [NSMutableDictionary new];
    
    GraphDescriptor *waterConsumeGraph = [GraphDescriptor defaultDescriptor];
    waterConsumeGraph.graphIdentifier = kWaterConsumeGraphIdentifier;
    waterConsumeGraph.titleAreaDescriptor.title = @"Water Consume";
    waterConsumeGraph.titleAreaDescriptor.units = @"%";
    waterConsumeGraph.iconsBarDescriptor = [GraphIconsBarDescriptor defaultDescriptor];
    waterConsumeGraph.valuesBarDescriptor = [GraphValuesBarDescriptor defaultDescriptor];
    waterConsumeGraph.valuesBarDescriptor.units = @"°F";
    waterConsumeGraph.displayAreaDescriptor.graphStyle = [GraphStyleBars new];
    [availableGraphs addObject:waterConsumeGraph];
    availableGraphsDictionary[waterConsumeGraph.graphIdentifier] = waterConsumeGraph;
    
    
    GraphDescriptor *temperatureGraph = [GraphDescriptor defaultDescriptor];
    temperatureGraph.graphIdentifier = kTemperatureGraphIdentifier;
    temperatureGraph.titleAreaDescriptor.title = @"Temperature";
    temperatureGraph.titleAreaDescriptor.units = @"°F";
    temperatureGraph.displayAreaDescriptor.graphStyle = [GraphStyleLines new];
    [availableGraphs addObject:temperatureGraph];
    availableGraphsDictionary[temperatureGraph.graphIdentifier] = temperatureGraph;
    
    GraphDescriptor *totalProgramRuntimesGraph = [GraphDescriptor defaultDescriptor];
    totalProgramRuntimesGraph.graphIdentifier = kTotalProgramRuntimesGraphIdentifier;
    totalProgramRuntimesGraph.titleAreaDescriptor.title = @"Total Program Runtimes";
    totalProgramRuntimesGraph.titleAreaDescriptor.units = @"%";
    totalProgramRuntimesGraph.iconsBarDescriptor = [GraphIconsBarDescriptor defaultDescriptor];
    totalProgramRuntimesGraph.valuesBarDescriptor = [GraphValuesBarDescriptor defaultDescriptor];
    totalProgramRuntimesGraph.valuesBarDescriptor.units = @"°F";
    totalProgramRuntimesGraph.displayAreaDescriptor.graphStyle = [GraphStyleBars new];
    [availableGraphs addObject:totalProgramRuntimesGraph];
    availableGraphsDictionary[totalProgramRuntimesGraph.graphIdentifier] = totalProgramRuntimesGraph;
    
    self.availableGraphsDictionary = availableGraphsDictionary;
    self.availableGraphs = availableGraphs;
}

- (void)selectGraph:(GraphDescriptor*)graph {
    if ([self.selectedGraphs containsObject:graph]) return;
    self.selectedGraphs = [self.selectedGraphs arrayByAddingObject:graph];
}

- (void)deselectGraph:(GraphDescriptor*)graph {
    if (![self.selectedGraphs containsObject:graph]) return;
    NSMutableArray *selectedGraphs = [NSMutableArray arrayWithArray:self.selectedGraphs];
    [selectedGraphs removeObject:graph];
    self.selectedGraphs = selectedGraphs;
}

- (void)selectAllGraphs {
    if (!self.selectedGraphs.count) self.selectedGraphs = [NSArray arrayWithArray:self.availableGraphs];
}

- (void)moveGraphFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    GraphDescriptor *graph = [self.selectedGraphs objectAtIndex:sourceIndex];
    
    NSMutableArray *selectedGraphs = [NSMutableArray arrayWithArray:self.selectedGraphs];
    [selectedGraphs removeObjectAtIndex:sourceIndex];
    [selectedGraphs insertObject:graph atIndex:destinationIndex];
    
    _selectedGraphs = selectedGraphs;
}

- (void)replaceGraphAtIndex:(NSInteger)index withGraph:(GraphDescriptor*)graph {
    NSMutableArray *selectedGraphs = [NSMutableArray arrayWithArray:self.selectedGraphs];
    [selectedGraphs replaceObjectAtIndex:index withObject:graph];
    
    _selectedGraphs = selectedGraphs;
}

#pragma mark - Randomize test data

static BOOL GraphsManagerRandomizeTestData = NO;

+ (void)setRandomizeTestData:(BOOL)randomizeTestData {
    if (GraphsManagerRandomizeTestData == randomizeTestData) return;
    
    srand((unsigned)time(NULL));
    GraphsManagerRandomizeTestData = randomizeTestData;
    sharedGraphsManager = nil;
}

+ (BOOL)randomizeTestData {
    return GraphsManagerRandomizeTestData;
}

@end

#pragma mark - Empty graph descriptor

@implementation EmptyGraphDescriptor {
    CGFloat _totalGraphHeight;
}

+ (EmptyGraphDescriptor*)emptyGraphDescriptorWithTotalGraphHeight:(CGFloat)totalGraphHeight {
    return [[self alloc] initWithTotalGraphHeight:totalGraphHeight];
}

- (id)initWithTotalGraphHeight:(CGFloat)totalGraphHeight {
    self = [super init];
    if (!self) return nil;
    
    _totalGraphHeight = totalGraphHeight;
    self.graphIdentifier = kEmptyGraphIdentifier;
    
    return self;
}

- (CGFloat)totalGraphHeight {
    return _totalGraphHeight;
}

@end