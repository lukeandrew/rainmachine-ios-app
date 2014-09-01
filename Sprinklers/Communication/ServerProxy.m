//
//  SPServerProxy.m
//  AFNetworking iOS Example
//
//  Created by Fabian Matyas on 02/12/13.
//  Copyright (c) 2013 Gowalla. All rights reserved.
//

#import "ServerProxy.h"
#import <objc/runtime.h>
#import "AFHTTPRequestOperationManager.h"
#import "WeatherData.h"
#import "WeatherData4.h"
#import "RestrictionsData.h"
#import "WaterNowZone.h"
#import "StartStopWatering.h"
#import "SetRainDelay.h"
#import "ServerResponse.h"
#import "Utils.h"
#import "Program.h"
#import "APIVersion.h"
#import "APIVersion4.h"
#import "UpdateInfo.h"
#import "UpdateInfo4.h"
#import "UpdateStartInfo.h"
#import "StorageManager.h"
#import "RainDelay.h"
#import "SettingsUnits.h"
#import "SettingsDate.h"
#import "SettingsPassword.h"
#import "StartStopProgramResponse.h"
#import "AppDelegate.h"
#import "UpdateManager.h"
#import "Login4Response.h"
#import "SetPassWord4Response.h"
#import "SettingsDate.h"
#import "NetworkUtilities.h"
#import "API4ErrorResponse.h"

static int serverAPIMainVersion = 0;
static int serverAPISubVersion = 0;
static int serverAPIMinorSubVersion = -1;

@implementation ServerProxy

- (id)initWithSprinkler:(Sprinkler *)sprinkler delegate:(id<SprinklerResponseProtocol>)del jsonRequest:(BOOL)jsonRequest {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSString *serverURL = [Utils sprinklerURL:sprinkler];
    
    self.delegate = del;
    self.serverURL = serverURL;

    NSURL *baseURL = [NSURL URLWithString:serverURL];
    self.manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL jsonRequest:jsonRequest];

    // TODO: remove invalid certificates policy in the future
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    [self.manager setSecurityPolicy:policy];
    
    return self;
}

- (void)cancelAllOperations
{
    [self.manager.operationQueue cancelAllOperations];
}

- (int)operationCount
{
    return (int)(self.manager.operationQueue.operationCount);
}

+ (void)setSprinklerVersionMajor:(int)major minor:(int)minor subMinor:(int)subMinor
{
    serverAPIMainVersion = major;
    serverAPISubVersion = minor;
    serverAPIMinorSubVersion = subMinor;
}

+ (int)serverAPIMainVersion
{
    return serverAPIMainVersion;
}

+ (int)usesAPI3
{
    return serverAPIMainVersion < 4;
}

+ (int)usesAPI4
{
    return serverAPIMainVersion >= 4;
}

#pragma mark - Login

- (void)loginWithUserName:(NSString*)userName password:(NSString*)password rememberMe:(BOOL)rememberMe
{
    if ([ServerProxy usesAPI3]) {
        [self login3WithUserName:userName password:password rememberMe:rememberMe];
    } else {
        [self login4WithPassword:password rememberMe:rememberMe];
    }
}

- (void)login4WithPassword:(NSString*)password rememberMe:(BOOL)rememberMe
{
    NSDictionary *paramsDic = @{@"pwd": !password ? @"" : password,
                  @"remember": rememberMe ? @1 : @0
                  };
    
    [self.manager POST:@"api/4/login" parameters:paramsDic
               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                   if ([self passLoggedOutFilter:operation]) {
                       [self.delegate loginSucceededAndRemembered:[self isLoginRememberedForCurrentSprinkler] unit:nil];
                   }
                   
               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                   [self handleError:error fromOperation:operation userInfo:nil];
               }];
}

- (void)login3WithUserName:(NSString*)userName password:(NSString*)password rememberMe:(BOOL)rememberMe
{
    NSDictionary *paramsDic;
    if (rememberMe) {
        paramsDic = @{@"action": @"login",
                      @"user": !userName ? @"" : userName,
                      @"password": !password ? @"" : password,
                      @"remember": @"true"
                      };
    } else {
        paramsDic = @{@"action": @"login",
                      @"user": !userName ? @"" : userName,
                      @"password": !password ? @"" : password
                      };
    }
    
    [self.manager POST:@"/ui.cgi" parameters:paramsDic
                                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                         //DLog(@"Success code: %d", [[operation response] statusCode]);
                                         [self step2LoginProcess];
                                    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                      BOOL success = NO;
                                      if ([[NetworkUtilities cookiesForURL:[self.manager baseURL]] count] > 0) {
                                        if ([[[operation response] MIMEType] isEqualToString:@"text/html"]) {
                                        success = YES;
                                        }
                                      }
                                      if (success) {
                                          [self step2LoginProcess];
                                      } else {
                                        NSHTTPURLResponse *response = operation.response;
                                        if ((NSUInteger)response.statusCode == 200) {
                                          [self.delegate loggedOut];
                                        } else {
                                            [self handleError:error fromOperation:operation userInfo:nil];
                                        }
                                      }
                                  }];
}

- (void)step2LoginProcess
{
    // This step is in fact a test for the case when the device logs the user out immediately after login
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings",
                                             @"what" : @"units"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                 
                                                 if ([self passLoggedOutFilter:operation]) {
                                                     NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:[responseObject objectForKey:@"settings"]] toClass:NSStringFromClass([SettingsUnits class])];
                                                     SettingsUnits *response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                                                     [self.delegate loginSucceededAndRemembered:[self isLoginRememberedForCurrentSprinkler] unit:response.units];
                                                 }
                                                 
                                             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                 [self handleError:error fromOperation:operation userInfo:nil];
                                             }];
}

- (BOOL)isLoginRememberedForCurrentSprinkler
{
    NSArray *cookies = [NetworkUtilities cookiesForURL:[self.manager baseURL]];
    for (NSHTTPCookie *cookie in cookies) {
        if (([[cookie name] isEqualToString:@"login"]) && (![cookie isSessionOnly])) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Settings

- (void)setNewPassword:(NSString*)newPassword confirmPassword:(NSString*)confirmPassword oldPassword:(NSString*)oldPassword
{
    if ([ServerProxy usesAPI3]) {
        [self setNewPassword3:newPassword confirmPassword:confirmPassword oldPassword:oldPassword];
    } else {
        [self setNewPassword4:newPassword oldPassword:oldPassword];
    }
}

- (void)setNewPassword4:(NSString*)newPassword oldPassword:(NSString*)oldPassword
{
    NSDictionary *paramsDic = @{@"newPass" : newPassword,
                                @"oldPass": oldPassword
                                };

    [self.manager POST: @"api/4/password" parameters:paramsDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([SetPassword4Response class])] serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)setNewPassword3:(NSString*)newPassword confirmPassword:(NSString*)confirmPassword oldPassword:(NSString*)oldPassword
{
    [self.manager POST:@"/ui.cgi?action=settings&what=password" parameters:@{@"newPass" : newPassword,
                                                                             @"confirmPass" : confirmPassword,
                                                                             @"oldPass" : oldPassword
                                                                             } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            ServerResponse *response = nil;
            if (responseObject) {
                NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            }
            [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestSettingsUnits
{
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings",
                                              @"what" : @"units"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:[responseObject objectForKey:@"settings"]] toClass:NSStringFromClass([SettingsUnits class])];
            ServerResponse *response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)setSettingsUnits:(NSString*)unit
{
    [self.manager POST:@"/ui.cgi?action=settings&what=units" parameters:@{@"units": unit} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                  
      if ([self passLoggedOutFilter:operation]) {
          ServerResponse *response = nil;
          if (responseObject) {
              NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
              response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
          }
          [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
      }
      
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestSettingsDate
{
    if ([ServerProxy usesAPI3]) {
        [self requestSettingsDate3];
    } else {
        [self requestSettingsDate4];
    }
}

- (void)requestSettingsDate4
{
    [self.manager GET: @"api/4/time" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            SettingsDate *settingsDate = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([SettingsDate class])][0];
            settingsDate.time_format = @24;
            [self.delegate serverResponseReceived:settingsDate serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestSettingsDate3
{
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings",
                                             @"what" : @"timedate"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                 
                                                 if ([self passLoggedOutFilter:operation]) {
                                                     NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:[responseObject objectForKey:@"settings"]] toClass:NSStringFromClass([SettingsDate class])];
                                                     SettingsDate *response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                                                     response = [Utils fixedSettingsDate:response];
                                                     [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
                                                 }
                                                 
                                             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                 [self handleError:error fromOperation:operation userInfo:nil];
                                             }];
}

- (void)setSettingsDate:(SettingsDate*)settingsDate
{
    NSDictionary *params = [self toDictionaryFromObject:settingsDate];
    
    [self.manager POST:@"/ui.cgi?action=settings&what=timedate" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            ServerResponse *response = nil;
            if (responseObject) {
                NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            }
            [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestSettingsPassword
{
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings",
                                             @"what" : @"password"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                 
                                                 if ([self passLoggedOutFilter:operation]) {
                                                     NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:[responseObject objectForKey:@"settings"]] toClass:NSStringFromClass([SettingsPassword class])];
                                                     ServerResponse *response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                                                     [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
                                                 }
                                                 
                                             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                 [self handleError:error fromOperation:operation userInfo:nil];
                                             }];
}

- (void)setSettingsPassword:(SettingsPassword*)settingsPassword
{
    NSDictionary *params = [self toDictionaryFromObject:settingsPassword];
    
    [self.manager POST:@"/ui.cgi?action=settings&what=password" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            ServerResponse *response = nil;
            if (responseObject) {
                NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            }
            [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

#pragma mark - Various

- (void)requestWateringRestrictions
{
    DLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.manager GET:@"/api/4/wateringrestrictions" parameters: nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[responseObject objectForKey:@"wateringrestrictions"] toClass:NSStringFromClass([RestrictionsData class])] serverProxy:self userInfo:nil];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestWeatherData
{
    if ([ServerProxy usesAPI3]) {
        [self request3WeatherData];
    } else {
        [self request4WeatherData];
    }
}

- (void)request4WeatherData
{
    [self.manager GET: @"api/4/weatherData" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[responseObject objectForKey:@"WeatherData"] toClass:NSStringFromClass([WeatherData4 class])] serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)request3WeatherData
{
    [self.manager GET: @"ui.cgi" parameters:@{@"action": @"weatherdata"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[responseObject objectForKey: @"HomeScreen"] toClass:NSStringFromClass([WeatherData class])] serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

// Get Zones list (Used in Water Now main screen)
- (void)requestWaterNowZoneList
{
    if ([ServerProxy usesAPI3]) {
        [self requestWaterNowZoneList3];
    } else {
        [self requestWaterNowZoneList4];
    }
}

- (void)requestWaterNowZoneList3
{
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"zones"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[responseObject objectForKey:@"zones"] toClass:NSStringFromClass([WaterNowZone class])] serverProxy:self userInfo:nil];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestWaterNowZoneList4
{
    [self.manager GET:@"api/4/waterNowZone" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:[ServerProxy fromJSONArray:[responseObject objectForKey:@"zones"] toClass:NSStringFromClass([WaterNowZone class])] serverProxy:self userInfo:nil];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

// Request one single zone (Used in Water Now->Zone screen)
- (void)requestWaterActionsForZone:(NSNumber*)zoneId
{
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"zoneedit",
                                             @"zid": zoneId} success:^(AFHTTPRequestOperation *operation, id responseObject) {

                                                 if ([self passLoggedOutFilter:operation]) {
                                                     NSDictionary *zoneDict = [responseObject objectForKey:@"zone"];
                                                     if ([zoneDict isKindOfClass:[NSDictionary class]]) {
                                                         WaterNowZone *zone = [WaterNowZone createFromJson:zoneDict];
                                                         [self.delegate serverResponseReceived:zone serverProxy:self userInfo:nil];
                                                     }
                                                 }

                                             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                 [self handleError:error fromOperation:operation userInfo:nil];
                                             }];
}

// Toggle a zone (Used in Water Now->Zone screen and when toggling watering using switches from main screen)
// Return value means: YES - if watering started, NO - if watering stopped
- (BOOL)toggleWateringOnZone:(WaterNowZone*)zone withCounter:(NSNumber*)counter
{
    BOOL isIdle = [Utils isZoneIdle:zone];
    StartStopWatering *startStopWatering = [StartStopWatering new];
    startStopWatering.id = zone.id;
    startStopWatering.counter = isIdle ? [Utils fixedZoneCounter:counter isIdle:isIdle] : [NSNumber numberWithInteger:0];

    zone.counter = startStopWatering.counter;
    
    NSDictionary *params = [self toDictionaryFromObject:startStopWatering];
    [self.manager POST:[NSString stringWithFormat:@"/ui.cgi?action=zonesave&from=zoneedit&zid=%@", zone.id] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        // The server returns an empty response when success
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:nil serverProxy:self userInfo:nil];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
    
    return [startStopWatering.counter intValue] != 0;
}

- (BOOL)setWateringOnZone:(WaterNowZone*)zone toState:(int)state withCounter:(NSNumber*)counter
{
    StartStopWatering *startStopWatering = [StartStopWatering new];
    startStopWatering.id = zone.id;
    startStopWatering.counter = state ? [Utils fixedZoneCounter:counter isIdle:YES] : [NSNumber numberWithInteger:0];
    
    zone.counter = startStopWatering.counter;
    
    NSDictionary *params = [self toDictionaryFromObject:startStopWatering];
    [self.manager POST:[NSString stringWithFormat:@"/ui.cgi?action=zonesave&from=zoneedit&zid=%@", zone.id] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        // The server returns an empty response when success
        if ([self passLoggedOutFilter:operation]) {
            [self.delegate serverResponseReceived:nil serverProxy:self userInfo:nil];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
    
    return [startStopWatering.counter intValue] != 0;
}

- (void)stopAllWateringZones
{
    [self.manager GET:@"/ui.cgi?action=stopall" parameters:@{@"action": @"stopall"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
    
         if ([self passLoggedOutFilter:operation]) {
             ServerResponse *response = nil;
             if (responseObject) {
                 NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                 response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
             }
             [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
         }
         
     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         [self handleError:error fromOperation:operation userInfo:nil];
     }];
}

- (void)getRainDelay {
    if ([ServerProxy usesAPI3]) {
        [self getRainDelay3];
    } else {
        [self getRainDelay4];
    }
}

- (void)getRainDelay4 {
    [self.manager GET: @"api/4/rainDelay" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            id responseArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([RainDelay class])];
            [self.delegate serverResponseReceived:responseArray[0] serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)getRainDelay3 {
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings", @"what": @"rainDelay"}
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  if ([self passLoggedOutFilter:operation]) {
                      NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:[responseObject objectForKey:@"settings"]] toClass:NSStringFromClass([RainDelay class])];
                      ServerResponse *response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                      [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
                  }
              }
              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [self handleError:error fromOperation:operation userInfo:nil];
              }];
}

- (void)setRainDelay:(NSNumber*)value
{
    if ([ServerProxy usesAPI3]) {
        [self setRainDelay3:value];
    } else {
        [self setRainDelay4:value];
    }
}

- (void)setRainDelay4:(NSNumber*)value {
    NSDictionary *params = [NSDictionary dictionaryWithObject:value forKey:@"rainDelay"];
    [self.manager POST: @"api/4/rainDelay" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            id responseArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([API4ErrorResponse class])];
            [self.delegate serverResponseReceived:responseArray[0] serverProxy:self userInfo:params];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)setRainDelay3:(NSNumber*)value
{
    NSDictionary *params = [NSDictionary dictionaryWithObject:value forKey:@"rainDelay"];
    [self.manager POST:@"/ui.cgi?action=settings&what=rainDelay" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self passLoggedOutFilter:operation]) {
            ServerResponse *response = nil;
            if (responseObject) {
                NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            }
            [self.delegate serverResponseReceived:response serverProxy:self userInfo:params];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (id)fixedZonesJSON:(AFHTTPRequestOperation*)operation
{
    // Relates to #124
    // The "forecastData" field comes duplicated from all sprinklers <= 3.60
    // This fix replaces all "forecastData:" strings with "forecastData%d:", parses the response to a dictionary and takes the last "forecastData%d" key
    
    NSMutableString *responseString = [[[NSString alloc] initWithData:[operation responseData] encoding:NSUTF8StringEncoding] mutableCopy];
    
    NSString *substring = @"\"forecastData\":";
    BOOL found = NO;
    int keyIndex = 0;
    do {
        found = NO;
        NSRange searchRange = NSMakeRange(0, responseString.length);
        NSRange foundRange;
        if (searchRange.location < responseString.length) {
            searchRange.length = responseString.length-searchRange.location;
            foundRange = [responseString rangeOfString:substring options:nil range:searchRange];
            if (foundRange.location != NSNotFound) {
                found = YES;
                NSString *newKey = [NSString stringWithFormat:@"\"forecastData%04d\":", keyIndex++];
                [responseString replaceCharactersInRange:foundRange withString:newKey];
            }
        }
    } while (found);
    
    NSError *error = nil;
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
    
    NSArray *values = [responseObject objectForKey:@"zones"];
    for (NSMutableDictionary *obj in values) {
        if ([obj isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableArray *keys = [NSMutableArray array];
            for (NSString *key in [obj allKeys]) {
                if ([key hasPrefix:@"forecastData"]) {
                    [keys addObject:key];
                }
            }
            
            NSArray *sortedKeys = [keys sortedArrayUsingSelector:@selector(compare:)];
            if ([sortedKeys count] > 0) {
                [obj setObject:[obj objectForKey:[sortedKeys lastObject]] forKey:@"forecastData"];

                // Remove the duplicate keys
                for (NSString *key in sortedKeys) {
                    [obj removeObjectForKey:key];
                }
            }
        }
    }
    
    return responseObject;
}

- (void)requestZones {
    if ([ServerProxy usesAPI3]) {
        [self requestZones3];
    } else {
        [self requestZones4];
    }
}

- (void)requestZones4 {
    [self.manager GET:@"api/4/zone" parameters:nil
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  if ([self passLoggedOutFilter:operation]) {
                      
                      responseObject = [self fixedZonesJSON:operation];
                      
                      NSArray *values = [responseObject objectForKey:@"zones"];
                      if (values) {
                          NSMutableArray *returnValues = [NSMutableArray array];
                          for (id obj in values) {
                              if ([obj isKindOfClass:[NSDictionary class]]) {
                                  Zone *zone = [Zone createFromJson:obj];
                                  [returnValues addObject:zone];
                              }
                          }
                          [_delegate serverResponseReceived:returnValues serverProxy:self userInfo:nil];
                      }
                  }
              }
              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [self handleError:error fromOperation:operation userInfo:nil];
              }];
}

- (void)requestZones3 {
    [self.manager GET:@"ui.cgi" parameters:@{@"action": @"settings", @"what": @"zones"}
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  if ([self passLoggedOutFilter:operation]) {
                      
                      responseObject = [self fixedZonesJSON:operation];

                      NSArray *values = [responseObject objectForKey:@"zones"];
                      if (values) {
                          NSMutableArray *returnValues = [NSMutableArray array];
                          for (id obj in values) {
                              if ([obj isKindOfClass:[NSDictionary class]]) {
                                  Zone *zone = [Zone createFromJson:obj];
                                  [returnValues addObject:zone];
                              }
                          }
                          [_delegate serverResponseReceived:returnValues serverProxy:self userInfo:nil];
                      }
                  }
              }
              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [self handleError:error fromOperation:operation userInfo:nil];
              }];
}

- (void)requestPrograms {
    [self.manager GET:@"ui.cgi" parameters:@{@"action" : @"settings", @"what" : @"programs"}
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  if ([self passLoggedOutFilter:operation]) {
                      NSArray *values = [responseObject objectForKey:@"programs"];
                      if (values) {
                          NSMutableArray *returnValues = [NSMutableArray array];
                          for (id obj in values) {
                              if ([obj isKindOfClass:[NSDictionary class]]) {
                                  Program *program = [Program createFromJson:obj];
                                  [returnValues addObject:program];
                              }
                          }
                          [_delegate serverResponseReceived:returnValues serverProxy:self userInfo:nil];
                      }
                  }
              }
              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [self handleError:error fromOperation:operation userInfo:nil];
              }];
}

- (void)runNowProgram:(Program*)program {
    if (program) {
        // 3.55 and 3.56 can only Stop programs
        [self.manager POST:@"/ui.cgi" parameters:@{@"action" : @"settings",
                                                   @"what" : [Utils isDevice357Plus] ? @"run_now" : @"stop_now",
                                                   @"pid" : [NSNumber numberWithInt:program.programId]}
         success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([self passLoggedOutFilter:operation]) {
                StartStopProgramResponse *response = nil;
                if (responseObject) {
                    NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([StartStopProgramResponse class])];
                    response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                }
                [self.delegate serverResponseReceived:response serverProxy:self userInfo:@"runNowProgram"];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self handleError:error fromOperation:operation userInfo:@"runNowProgram"];
        }];
    }
}

- (void)saveProgram:(Program*)program {
    if (program) {
        //        NSMutableDictionary *params = [[self toDictionaryFromObject:program] mutableCopy];
        //        [params setObject:[Utils formattedTime:program.startTime forTimeFormat:program.timeFormat] forKey:@"programStartTime"];
        //        [params removeObjectForKey:@"startTime"];
        NSDictionary *params = [program toDictionary];
        
        [self.manager POST:@"ui.cgi?action=settings&what=programs" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([self passLoggedOutFilter:operation]) {
                ServerResponse *response = nil;
                if (responseObject) {
                    NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                    response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                }
                [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self handleError:error fromOperation:operation userInfo:nil];
        }];
    }
}

- (void)deleteProgram:(int)programId {
    NSDictionary *paramsDic = @{@"action": @"settings",
                                @"what": @"delete_program",
                                @"pid": [NSNumber numberWithInt:programId]};

    [self.manager POST:@"/ui.cgi" parameters:paramsDic
       success:^(AFHTTPRequestOperation *operation, id responseObject) {
           if ([self passLoggedOutFilter:operation]) {
               ServerResponse *response = nil;
               if (responseObject) {
                   NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                   response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
               }
               NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:response, @"serverResponse", [NSNumber numberWithInt:programId], @"pid", nil];
               [_delegate serverResponseReceived:d serverProxy:self userInfo:nil];
           }
       }
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           [self handleError:error fromOperation:operation userInfo:nil];
       }];
}

- (void)programCycleAndSoak:(int)programId cycles:(int)nr_of_cycles soak:(int)soak_minutes cs_on:(int)cs_on
{
    NSDictionary *paramsDic = @{@"action": @"settings",
                                @"what": @"cycle_soak",
                                @"pid": [NSNumber numberWithInt:programId],
                                @"cycles" : [NSNumber numberWithInt:nr_of_cycles],
                                @"soak" : [NSNumber numberWithInt:soak_minutes],
                                @"cs_on" : [NSNumber numberWithInt:cs_on]
                                };
    
    [self.manager POST:@"/ui.cgi" parameters:paramsDic
               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                   if ([self passLoggedOutFilter:operation]) {
                       ServerResponse *response = nil;
                       if (responseObject) {
                           NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                           response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                       }
                       [_delegate serverResponseReceived:response serverProxy:self userInfo:paramsDic];
                   }
               }
               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                   [self handleError:error fromOperation:operation userInfo:nil];
               }];
}

- (void)programStationDelay:(int)programId delay:(int)delay_minutes delay_on:(int)delay_on
{
    NSDictionary *paramsDic = @{@"action": @"settings",
                                @"what": @"station_delay",
                                @"pid": [NSNumber numberWithInt:programId],
                                @"delay" : [NSNumber numberWithInt:delay_minutes],
                                @"delay_on" : [NSNumber numberWithInt:delay_on]
                                };
    
    [self.manager POST:@"/ui.cgi" parameters:paramsDic
               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                   if ([self passLoggedOutFilter:operation]) {
                       ServerResponse *response = nil;
                       if (responseObject) {
                           NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                           response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                       }
                       [_delegate serverResponseReceived:response serverProxy:self userInfo:paramsDic];
                   }
               }
               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                   [self handleError:error fromOperation:operation userInfo:nil];
               }];
}

- (void)saveZone:(Zone *)zone {
    if (zone) {
        NSDictionary *params = @{@"id" : @(zone.zoneId), @"active" : @(zone.active), @"after" : @(zone.after), @"before": @(zone.before),
                                 @"forecastData" : @(zone.forecastData), @"historicalAverage" : @(zone.historicalAverage), @"masterValve" : @(zone.masterValve),
                                 @"name" : zone.name, @"vegetation" : [NSString stringWithFormat:@"%d", zone.vegetation]};
        NSString *url = [NSString stringWithFormat:@"ui.cgi?action=settings&what=zones&zid=%d", zone.zoneId];
        [self.manager POST:url parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([self passLoggedOutFilter:operation]) {
                NSArray *response = nil;
                if (responseObject) {
                    NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([ServerResponse class])];
                    response = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
                }
                [self.delegate serverResponseReceived:response serverProxy:self userInfo:nil];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self handleError:error fromOperation:operation userInfo:nil];
        }];
    }
}

- (void)requestUpdateStartForVersion:(int)version
{
    NSString *requestUrl = [NSString stringWithFormat:@"api/%d/update", version];
    [self.manager POST:requestUrl parameters:@{@"update": [NSNumber numberWithBool:YES]} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            NSArray *parsedArray = [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([UpdateStartInfo class])];
            UpdateStartInfo *updateStartInfo = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            [self.delegate serverResponseReceived:updateStartInfo serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestUpdateCheckForVersion:(int)version
{
    NSString *requestUrl = [NSString stringWithFormat:@"api/%d/update", version];
    [self.manager GET:requestUrl parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            id updateInfo = nil;
            if ([ServerProxy usesAPI3]) {
                UpdateInfo *updateInfo3 = [UpdateInfo createFromJson:responseObject];
                updateInfo = updateInfo3;
            } else {
                UpdateInfo4 *updateInfo4 = [UpdateInfo4 createFromJson:responseObject];
                updateInfo = updateInfo4;
            }
            [self.delegate serverResponseReceived:updateInfo serverProxy:self userInfo:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:nil];
    }];
}

- (void)requestAPIVersion
{
    [self.manager GET:@"api/apiVer" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([self passLoggedOutFilter:operation]) {
            NSArray *parsedArray = responseObject ? [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([APIVersion class])] : nil;
            APIVersion *version = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            if (!version.apiVer) {
                // Most likely the response is from API4
                NSArray *parsedArray = responseObject ? [ServerProxy fromJSONArray:[NSArray arrayWithObject:responseObject] toClass:NSStringFromClass([APIVersion4 class])] : nil;
                version = ([parsedArray count] > 0) ? [parsedArray firstObject] : nil;
            }
            [self.delegate serverResponseReceived:version serverProxy:self userInfo:@"apiVer"];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error fromOperation:operation userInfo:@"apiVer"];
    }];
}

- (void)handleError:(NSError *)error fromOperation:(AFHTTPRequestOperation *)operation userInfo:(id)userInfo {
    if ([self passLoggedOutFilter:operation]) {
        // Just a simple error
        DLog(@"NetworkError: %@", error);
        BOOL cancelled = ([error code] == NSURLErrorCancelled) && ([[error domain] isEqualToString:NSURLErrorDomain]);
        if (!cancelled) {
            [_delegate serverErrorReceived:error serverProxy:self operation:operation userInfo:userInfo];
        }
    }
}

- (BOOL)passLoggedOutFilter:(AFHTTPRequestOperation *)operation
{
    if ([self isLoggedOut:operation]) {
        DLog(@"NetworkError. Logged out error received");
        [self.delegate loggedOut];
        return NO;
    }

    return YES;
}

- (BOOL)isLoggedOut:(AFHTTPRequestOperation *)operation
{
    BOOL isLoggedOut = NO;
    NSData *responseData = [operation responseData];
    if ([ServerProxy usesAPI3]) {
        if ([@"{ \"status\":\"OUT\",\"message\":\"LOgged OUT\"}" isEqualToString:[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]]) {
            return YES;
        }
        
        if ((([[[operation response] MIMEType] isEqualToString:@"json/html"]) ||
             ([[[operation response] MIMEType] isEqualToString: @"text/plain"])) &&
            (responseData)) {
            NSError *jsonError = nil;
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:responseData options:nil error:&jsonError];
            if (!jsonError) {
                if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                    // On Android, the 'status' field length is tested. Make it so on iOS too. (See mail on Apr 29)
                    if (([[jsonObject objectForKey:@"message"] isEqualToString:@"LOgged OUT"]) &&
                        ([[jsonObject objectForKey:@"status"] length] > 0)) {
                        isLoggedOut = YES;
                    }
                }
            }
        }
    } else {
        if (responseData) {
            NSError *jsonError = nil;
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:responseData options:nil error:&jsonError];
            if ((API4StatusCode)[[jsonObject objectForKey:@"statusCode"] intValue] == API4StatusCode_LoggedOut) {
                isLoggedOut = YES;
            }
        }
    }

    return isLoggedOut;
}

#pragma mark - Response/request objects conversion

+ (NSArray*)fromJSONArray:(NSArray*)jsonArray toClass:(NSString*)className
{
    NSMutableArray *responseArray = [NSMutableArray array];
    for (NSDictionary *jsonDic in jsonArray) {
        [responseArray addObject:[ServerProxy fromJSON:jsonDic toClass:className]];
    }
    
    return responseArray;
}

+ (id)fromJSON:(NSDictionary*)jsonDic toClass:(NSString*)className
{
    Class ObjectClass = NSClassFromString(className);
    
    if (ObjectClass == nil) {
        DLog(@"Error: class of type '%@' doesn't exist.", className);
        return nil;
    }
    
    NSObject* loadedObject = [[ObjectClass alloc] init];
    
    for (NSString *key in jsonDic) {
        if ([loadedObject respondsToSelector:NSSelectorFromString(key)]) {
            // Use the following lines to debug types of received data members
//            objc_property_t property = class_getProperty(ObjectClass, [key UTF8String]);
//            const char * type = property_getAttributes(property);
//            NSString *typeString = [NSString stringWithUTF8String:type];
//            NSArray *attributes = [typeString componentsSeparatedByString:@","];
//            Class typeAttributeClass = NSClassFromString([attributes objectAtIndex:0]);
//            NSLog(@"%@. type in dict:%@ type in receiving class:%@", key, NSStringFromClass([[jsonDic valueForKey:key] class]), typeAttributeClass);
            [loadedObject setValue:[jsonDic valueForKey:key] forKey:key];
        } else {
            DLog(@"Error: response object of class %@ doesn't implement property '%@' of type %@", className, key, NSStringFromClass([[jsonDic valueForKey:key] class]));
        }
    }
    
    return loadedObject;
}

- (NSDictionary *)toDictionaryFromObject:(id)object {
    unsigned int outCount, i;
    NSMutableDictionary *dict = [NSMutableDictionary new];
    objc_property_t *properties = class_copyPropertyList([object class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if (propName) {
            NSString *propertyName = [NSString stringWithCString:propName encoding:[NSString defaultCStringEncoding]];
            id prop = [object valueForKey:propertyName];
            if ([prop isKindOfClass:[NSDate class]]) {
                NSDate *date = (NSDate*)prop;
                [dict setObject:[NSNumber numberWithDouble:[date timeIntervalSince1970]] forKey:propertyName];
            }
            else if ([prop isKindOfClass:[NSArray class]]) {
                NSMutableArray *archivedArray = [NSMutableArray array];
                NSArray *array = (NSArray *)prop;
                for (id obj in array) {
                    [archivedArray addObject:[self toDictionaryFromObject:obj]];
                }
                [dict setObject:archivedArray forKey:propertyName];
            } else {
                id objectValue = [object valueForKey:propertyName];
                if (objectValue) {
                    [dict setObject:objectValue forKey:propertyName];
                }
            }
        }
    }
    free(properties);
    
    return dict;
}

- (NSData*)toJSONFromObject:(id)object {
    NSDictionary *dict = [self toDictionaryFromObject:object];
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    //  NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (error) {
        DLog(@"Error encoding object of type '%@': %@", NSStringFromClass([object class]), error);
    }
    return data;
}

@end
