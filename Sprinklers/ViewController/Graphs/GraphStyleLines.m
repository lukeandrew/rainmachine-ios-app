//
//  GraphStyleLines.m
//  Sprinklers
//
//  Created by Istvan Sipos on 10/12/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GraphStyleLines.h"
#import "GraphDescriptor.h"
#import "GraphTimeInterval.h"
#import "GraphVisualAppearanceDescriptor.h"
#import "GraphDisplayAreaDescriptor.h"

@implementation GraphStyleLines

- (void)plotGraphInRect:(CGRect)rect context:(CGContextRef)context {
    CGContextSaveGState(context);
    
    double maxValue = 0;
    for (id value in self.values) {
        if (value == [NSNull null]) continue;
        NSNumber *numberValue = (NSNumber*)value;
        if (numberValue.doubleValue > maxValue) maxValue = ceil(numberValue.doubleValue);
    }
    
    CGContextSetStrokeColorWithColor(context, self.graphDescriptor.displayAreaDescriptor.graphDisplayColor.CGColor);
    CGContextSetFillColorWithColor(context, self.graphDescriptor.visualAppearanceDescriptor.backgroundColor.CGColor);
    CGContextSetLineWidth(context, 1.0 / [UIScreen mainScreen].scale);
    
    CGFloat graphCirclesRadius = (self.graphDescriptor.graphTimeInterval ? [self.graphDescriptor.displayAreaDescriptor.graphCirclesRadiusDictionary[@(self.graphDescriptor.graphTimeInterval.type)] doubleValue] : 0.0);
    
    CGFloat graphTopPadding = self.graphDescriptor.displayAreaDescriptor.graphBarsTopPadding + self.graphDescriptor.displayAreaDescriptor.valuesDisplayHeight;
    CGFloat graphBottomPadding = self.graphDescriptor.displayAreaDescriptor.graphBarsBottomPadding - 1.0;
    CGFloat displayHeight = rect.size.height - graphTopPadding - graphBottomPadding;
    CGFloat displayWidth = rect.size.width - self.graphDescriptor.visualAppearanceDescriptor.graphContentLeadingPadding - self.graphDescriptor.visualAppearanceDescriptor.graphContentTrailingPadding;
    
    CGFloat barDisplayWidth = displayWidth / self.values.count;
    CGFloat barCenterX = self.graphDescriptor.visualAppearanceDescriptor.graphContentLeadingPadding + barDisplayWidth / 2.0;
    CGFloat oldBarCenterX = barCenterX;
    
    NSMutableArray *values = [NSMutableArray arrayWithArray:self.values];
    if (self.prevValue) {
        [values insertObject:self.prevValue atIndex:0];
        barCenterX -=barDisplayWidth;
    }
    if (self.nextValue) [values addObject:self.nextValue];
    
    BOOL firstPoint = YES;
    for (id value in values) {
        if (value == [NSNull null]) {
            CGContextStrokePath(context);
            barCenterX += barDisplayWidth;
            firstPoint = YES;
            continue;
        }
        
        NSNumber *numberValue = (NSNumber*)value;
        
        CGFloat absoluteValue = (numberValue.doubleValue - self.graphDescriptor.displayAreaDescriptor.minValue);
        CGFloat valuesIntervalLength = (self.graphDescriptor.displayAreaDescriptor.maxValue - self.graphDescriptor.displayAreaDescriptor.minValue);
        if (valuesIntervalLength == 0.0) valuesIntervalLength = 1.0;
        
        CGFloat barSizeHeight = absoluteValue / valuesIntervalLength * displayHeight;
        CGFloat barCenterY = rect.size.height - barSizeHeight - graphBottomPadding;
        
        if (firstPoint) CGContextMoveToPoint(context, round(barCenterX), round(barCenterY));
        else CGContextAddLineToPoint(context, round(barCenterX), round(barCenterY));
        
        firstPoint = NO;
        barCenterX += barDisplayWidth;
    }
    
    CGContextStrokePath(context);
    
    if (graphCirclesRadius > 0.0) {
        barCenterX = oldBarCenterX;
        
        for (id value in self.values) {
            if (value == [NSNull null]) {
                barCenterX += barDisplayWidth;
                continue;
            }
            
            NSNumber *numberValue = (NSNumber*)value;
            
            CGFloat absoluteValue = (numberValue.doubleValue - self.graphDescriptor.displayAreaDescriptor.minValue);
            CGFloat valuesIntervalLength = (self.graphDescriptor.displayAreaDescriptor.maxValue - self.graphDescriptor.displayAreaDescriptor.minValue);
            if (valuesIntervalLength == 0.0) valuesIntervalLength = 1.0;
            
            CGFloat barSizeHeight = absoluteValue / valuesIntervalLength * displayHeight;
            CGFloat barCenterY = rect.size.height - barSizeHeight - graphBottomPadding;
            CGRect circleRect = CGRectIntegral(CGRectMake(barCenterX - graphCirclesRadius, barCenterY - graphCirclesRadius, graphCirclesRadius * 2.0, graphCirclesRadius * 2.0));
            
            CGContextFillEllipseInRect(context, circleRect);
            CGContextStrokeEllipseInRect(context, circleRect);
            
            barCenterX += barDisplayWidth;
        }
    }
    
    CGContextRestoreGState(context);
}

@end
