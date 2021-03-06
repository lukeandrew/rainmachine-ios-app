//
//  UpdateManager.m
//  Sprinklers
//
//  Created by Fabian Matyas on 30/01/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "UpdateManager.h"
#import "ServerProxy.h"
#import "APIVersion.h"
#import "APIVersion4.h"
#import "UpdateInfo.h"
#import "UpdateInfo4.h"
#import "UpdateInfo4PackageDetails.h"
#import "UpdateStartInfo.h"
#import "Utils.h"
#import "Constants.h"
#import "StorageManager.h"
#import "UpdaterVC.h"
#import "StartStopProgramResponse.h"
#import "Program.h"
#import "AppDelegate.h"

@interface UpdateManager () {
    int serverAPIMainVersion;
    int serverAPISubVersion;
    int serverAPIMinorSubVersion;
    int retryCount;
}

@property (strong, nonatomic) ServerProxy *serverProxy;
@property (strong, nonatomic) ServerProxy *serverProxyDetect35x;
@property (strong, nonatomic) UIAlertView *alertView;
@property (weak, nonatomic) id<UpdateManagerDelegate> delegate;

@end

@implementation UpdateManager

@synthesize serverAPIMainVersion, serverAPISubVersion, serverAPIMinorSubVersion;

- (instancetype)initWithDelegate:(id<UpdateManagerDelegate>)delegate {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.delegate = delegate;
    retryCount = 0;
    
    serverAPIMainVersion = -1;
    serverAPISubVersion = -1;
    serverAPIMinorSubVersion = -1;

    return self;
}

- (void)stopAll
{
    [self.serverProxyDetect35x cancelAllOperations];
    self.serverProxyDetect35x = nil;

    [self.serverProxy cancelAllOperations];
    self.serverProxy = nil;
}

- (void)stop
{
    [self.serverProxy cancelAllOperations];
    self.serverProxy = nil;
}

- (void)retry
{
    DLog(@"UpdateManager: retry...");
    if (retryCount > 0) {
        retryCount--;
        [self internalPoll];
    }
}

// This method is called from outside this class
- (void)poll
{
    retryCount = 1;
    
    [self internalPoll];
}

// This method is called from inside this class
- (void)internalPoll
{
    // Initialize with lowest sprinkler type
    serverAPIMainVersion = 3;
    serverAPISubVersion = 56; // or 55;

    [self stop];
    
    BOOL checkUpdate = YES;
    
    if ([StorageManager current].currentSprinkler.lastSprinklerVersionRequest) {
        long intervalSinceLastUpdate = -[[StorageManager current].currentSprinkler.lastSprinklerVersionRequest timeIntervalSinceNow];
        checkUpdate = (intervalSinceLastUpdate >= kSprinklerUpdateCheckInterval);
    }
    
    if (checkUpdate) {

        if ([StorageManager current].currentSprinkler) {
            self.serverProxy = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:YES];
            [self.serverProxy requestAPIVersion];
        }
    }
}

- (void)serverErrorReceived:(NSError*)error serverProxy:(id)serverProxy operation:(AFHTTPRequestOperation *)operation userInfo:(id)userInfo
{
//    if ([Utils isConnectionFailToServerError:error]) {
//        [self handleSprinklerNetworkError:error operation:operation showErrorMessage:YES];
//    } else {
        if ([userInfo isEqualToString:@"apiVer"]) {
            if ([[operation response] statusCode] == 404) {
                // Device is 3.57 or lower. For now, suppose it is lower
                [self setSprinklerVersionMajor:3 minor:56 subMinor:-1]; // or 55;

                self.serverProxyDetect35x = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:NO];
                Program *program = [Program new];
                program.programId = -1;
                [self.serverProxyDetect35x runNowProgram:program];
            } else {
                // statusCode == 5xx or other. In this case the Sprinkler version is unknown for us.
                [self setSprinklerVersionMajor:0 minor:0 subMinor:-1];
                [self.delegate sprinklerVersionReceivedMajor:serverAPIMainVersion minor:serverAPISubVersion subMinor:serverAPIMinorSubVersion];
                [self.delegate updateNowAvailable:NO withVersion:nil currentVersion:nil];
                
                [self performSelector:@selector(retry) withObject:nil afterDelay:2.0];
            }
        }
        else if ([userInfo isEqualToString:@"runNowProgram"]) {
            self.serverProxyDetect35x = nil;

            // Error was received for some reason. Don't continue the update detection process
            [self.delegate sprinklerVersionReceivedMajor:serverAPIMainVersion minor:serverAPISubVersion subMinor:serverAPIMinorSubVersion];
            [self.delegate updateNowAvailable:NO withVersion:nil currentVersion:nil];
//            serverAPIMainVersion = 3;
//            serverAPISubVersion = 56; // or 55;
//            
//            if (!self.delegate) {
//                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Firmware update available"
//                                                                    message:@"Please go to your Rain Machine console and update to the latest version" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
//                [alertView show];
//            } else {
//                [self.delegate sprinklerVersionReceivedMajor:serverAPIMainVersion minor:serverAPISubVersion];
//            }
        }
        else {
            [self handleSprinklerNetworkError:error operation:operation showErrorMessage:YES];
        }
//    }
    
    [self.serverProxy cancelAllOperations];
    self.serverProxy = nil;
}

- (void)serverResponseReceived:(id)data serverProxy:(id)serverProxy userInfo:(id)userInfo
{
    [self handleSprinklerNetworkError:nil operation:nil showErrorMessage:YES];
    
    if (([userInfo isEqualToString:@"runNowProgram"]) && ([data isKindOfClass:[StartStopProgramResponse class]])) {
        StartStopProgramResponse *response = (StartStopProgramResponse*)data;
        if ([response.state isEqualToString:@"err"]) {
            [self setSprinklerVersionMajor:3 minor:57 subMinor:-1];
        } else {
            [self setSprinklerVersionMajor:3 minor:56 subMinor:-1];
        }
        
        self.serverProxyDetect35x = nil;
        
        if (!self.delegate) {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Firmware update available"
                            message:@"Please go to your Rain Machine console and update to the latest version" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
            [alertView show];
        } else {
            [self.delegate sprinklerVersionReceivedMajor:serverAPIMainVersion minor:serverAPISubVersion subMinor:serverAPIMinorSubVersion];
        }
    }
    else if (([data isKindOfClass:[APIVersion class]]) || ([data isKindOfClass:[APIVersion4 class]])) {
        NSArray *versionComponents = [Utils parseApiVersion:data];
        if ([versionComponents[0] intValue] >= 3) {
            // Firmware update is supported by server
            [self setSprinklerVersionMajor:[versionComponents[0] intValue]
                                     minor:[versionComponents[1] intValue]
                                  subMinor:(versionComponents.count > 2) ? [versionComponents[2] intValue] : -1];
            [self.delegate sprinklerVersionReceivedMajor:serverAPIMainVersion minor:serverAPISubVersion subMinor:serverAPIMinorSubVersion];
            [self.serverProxy requestUpdateCheckForVersion:serverAPIMainVersion];
        }
    }
    else if (([data isKindOfClass:[UpdateInfo class]]) || ([data isKindOfClass:[UpdateInfo4 class]])) {
        UpdateInfo *updateInfo = (UpdateInfo*)data;
        UpdateInfo4 *updateInfo4 = (UpdateInfo4*)data;
        
        NSString *newVersion = nil;
        NSString *currentVersion = nil;
        
        if ([ServerProxy usesAPI3]) {
            newVersion = updateInfo.the_new_version;
            currentVersion = updateInfo.current_version;
        } else {
            for (UpdateInfo4PackageDetails *packageDetails in updateInfo4.packageDetails) {
                if ([packageDetails.packageName isEqualToString:@"rainmachine-app"] || [packageDetails.packageName isEqualToString:@"rainmachine"]) {
                    newVersion = packageDetails.theNewVersion;
                    currentVersion = packageDetails.oldVersion;
                    break;
                }
            }
        }

        if ([updateInfo.update boolValue]) {
            NSTimeInterval intervalSinceLastUpdate;
            if ([ServerProxy usesAPI3]) {
                NSDate *lastUpdateCheck = [NSDate dateWithTimeIntervalSince1970:[updateInfo.last_update_check longLongValue]];
                intervalSinceLastUpdate = -[lastUpdateCheck timeIntervalSinceNow];
            } else {
                NSDate *lastUpdateCheck = [NSDate dateWithTimeIntervalSince1970:[updateInfo4.lastUpdateCheck longLongValue]];
                intervalSinceLastUpdate = -[lastUpdateCheck timeIntervalSinceNow];
            }
            // When there is a delegate alert it anyway with the update-now notification
            BOOL checkUpdate = (intervalSinceLastUpdate >= kSprinklerUpdateCheckInterval);
            
            if (checkUpdate) {
                if (!self.delegate) {
                    
                    NSString *message = [NSString stringWithFormat:@"Please update your device firmware to version %@.", newVersion];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Firmware Update Available"
                                                                    message:message delegate:self cancelButtonTitle:@"Later"
                                                          otherButtonTitles:@"Update Now", nil];
                    alert.tag = kAlertView_UpdateNow;
                    [alert show];
                }
            }
        }
        
        [self.delegate updateNowAvailable:[updateInfo.update boolValue]
                              withVersion:newVersion
                           currentVersion:currentVersion];
    }
    else if ([data isKindOfClass:[UpdateStartInfo class]]) {
        [self stop];
        UpdateStartInfo *updateInfo = (UpdateStartInfo*)data;
        if ([updateInfo.statusCode intValue] == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kFirmwareUpdateNeeded object:[NSNumber numberWithInt:serverAPIMainVersion]];
        }
    }
}

- (void)setSprinklerVersionMajor:(int)major minor:(int)minor subMinor:(int)subMinor
{
    serverAPIMainVersion = major;
    serverAPISubVersion = minor;
    serverAPIMinorSubVersion = subMinor;
    
    [ServerProxy setSprinklerVersionMajor:serverAPIMainVersion minor:serverAPISubVersion subMinor:subMinor];
}

- (void)loggedOut
{
    [self stop];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLoggedOutDetectedNotification object:nil];
}

- (void)startUpdate
{
    [self.serverProxy requestUpdateStartForVersion:serverAPIMainVersion];
}

- (void)alertView:(UIAlertView *)theAlertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (theAlertView.tag == kAlertView_UpdateNow) {
        if (buttonIndex != theAlertView.cancelButtonIndex) {
            [self startUpdate];
        }
    }
    else if (theAlertView.tag == kAlertView_Error) {
    }
    else if (theAlertView.tag == kAlertView_DeviceNotSupported) {
        [Utils invalidateLoginForCurrentSprinkler];
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate refreshRootViews:nil selectSettings:NO];
        
        if (buttonIndex != theAlertView.cancelButtonIndex) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/app/rainmachine/id647589286"]];
        }
    }

    self.alertView = nil;
}

- (void)handleSprinklerError:(NSString *)errorMessage title:(NSString*)titleMessage showErrorMessage:(BOOL)showErrorMessage{
    if ((errorMessage) && (showErrorMessage)) {
        self.alertView = [[UIAlertView alloc] initWithTitle:titleMessage message:errorMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        self.alertView.tag = kAlertView_Error;
        [self.alertView show];
    }
}

- (void)handleSprinklerNetworkError:(NSError*)error operation:(AFHTTPRequestOperation *)operation showErrorMessage:(BOOL)showErrorMessage {
    if (error) {
        NSDictionary *o = [NSDictionary dictionaryWithObjectsAndKeys:error, @"error", operation, @"operation", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSprinklerNetworkError object:o];
    }
}

- (void)handleServerLoggedOutUser {
    [[NSNotificationCenter defaultCenter] postNotificationName:kLoggedOutDetectedNotification object:nil];
}

@end
