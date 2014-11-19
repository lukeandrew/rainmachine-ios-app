//
//  GeocodingRequestAutocomplete.m
//  Sprinklers
//
//  Created by Istvan Sipos on 18/11/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "GeocodingRequestAutocomplete.h"
#import "GeocodingAutocompletePrediction.h"
#import "Constants.h"

@implementation GeocodingRequestAutocomplete

+ (instancetype)autocompleteGeocodingRequestWithInputString:(NSString*)inputString {
    return [[self alloc] initWithInputString:inputString];
}

- (instancetype)initWithInputString:(NSString*)inputString {
    self = [super initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:inputString,@"input",@"(cities)",@"types",nil]];
    if (!self) return nil;
    
    return self;
}

- (NSString*)geocodingRequestBaseURL {
    return @"https://maps.googleapis.com/maps/api/place/autocomplete";
}

- (NSString*)geocodingAPIKey {
    return kGooglePlacesAPIServerKey;
}

- (id)resultFromDictionary:(NSDictionary*)dictionary {
    NSArray *predictions = [dictionary valueForKey:@"predictions"];
    if (!predictions.count) return nil;
    
    NSMutableArray *predictionsArray = [NSMutableArray new];
    for (NSDictionary *dictionary in predictions) {
        [predictionsArray addObject:[GeocodingAutocompletePrediction autocompletePredictionWithDictionary:dictionary]];
    }
    
    return predictionsArray;
}

@end
