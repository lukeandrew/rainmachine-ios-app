//
//  WaterNowVC.m
//  Sprinklers
//
//  Created by Daniel Cristolovean on 17/12/13.
//  Copyright (c) 2013 Tremend. All rights reserved.
//

#import "WaterNowVC.h"
#import "Additions.h"
#import "DevicesVC.h"
#import "WaterNowLevel1VC.h"
#import "ServerProxy.h"
#import "Constants.h"
#import "WaterNowZone.h"
#import "MBProgressHUD.h"
#import "WaterZoneListCell.h"
#import "WaterNowLevel1VC.h"
#import "StartStopWatering.h"
#import "WaterNowZone.h"
#import "Utils.h"

@interface WaterNowVC () {
    UIColor *switchOnOrangeColor;
    UIColor *switchOnGreenColor;
    NSTimeInterval retryInterval;
}

@property (strong, nonatomic) MBProgressHUD *hud;
@property (strong, nonatomic) ServerProxy *pollServerProxy; // TODO: rename it to pollServerProxy or something better
@property (strong, nonatomic) ServerProxy *postServerProxy;
@property (strong, nonatomic) NSArray *zones;
@property (strong, nonatomic) NSDate *lastListRefreshDate;
@property (strong, nonatomic) NSError *lastScheduleRequestError;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation WaterNowVC

#pragma mark - Init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    if ([[UIDevice currentDevice] iOSGreaterThan:7]) {
//        UIEdgeInsets inset = {self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height, 0, 0, 0};
//        [self.tableView setContentInset:inset];
//    }
    
    [_tableView registerNib:[UINib nibWithNibName:@"WaterZoneListCell" bundle:nil] forCellReuseIdentifier:@"WaterZoneListCell"];

    switchOnGreenColor = [UIColor colorWithRed:70 / 255.0 green:225 / 255.0 blue:96 / 255.0 alpha:1];
    switchOnOrangeColor = [UIColor colorWithRed:255 / 255.0 green:101 / 255.0 blue:0 / 255.0 alpha:1];
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Stop All" style:UIBarButtonItemStylePlain target:self action:@selector(stopAll)];
    self.tabBarController.navigationItem.rightBarButtonItem = backButton;
    
    self.pollServerProxy = [[ServerProxy alloc] initWithServerURL:TestServerURL delegate:self jsonRequest:NO];
    self.postServerProxy = [[ServerProxy alloc] initWithServerURL:TestServerURL delegate:self jsonRequest:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //TODO: Load current sprinkler from SettingsManager here and update content if needed.
    
    [self requestListRefreshWithShowingHud:[NSNumber numberWithBool:YES]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.pollServerProxy cancelAllOperations];
    
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)startHud:(NSString *)text {
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.hud.labelText = text;
}

#pragma mark - Requests

- (void)requestListRefreshWithShowingHud:(NSNumber*)showHud
{
    [self.pollServerProxy requestWaterNowZoneList];
    
    self.lastListRefreshDate = [NSDate date];
    
    if ([showHud boolValue]) {
        [self startHud:nil]; // @"Receiving data..."
    }
}

- (void)scheduleNextListRefreshRequest:(NSTimeInterval)scheduleInterval
{
    if (self.isViewLoaded && self.view.window) {
        // viewController is visible
        NSTimeInterval t = [[NSDate date] timeIntervalSinceDate:self.lastListRefreshDate];
        if (t >= scheduleInterval) {
            [self requestListRefreshWithShowingHud:[NSNumber numberWithBool:NO]];
        } else {
            [self performSelector:@selector(requestListRefreshWithShowingHud:) withObject:[NSNumber numberWithBool:NO] afterDelay:scheduleInterval - t];
        }
    }
}

- (void)stopAll
{
    for (WaterNowZone *zone in self.zones) {
        BOOL watering = [Utils isZoneWatering:zone];
        if (watering) {
            [self toggleWatering:!watering onZone:zone withCounter:zone.counter];
        }
    }
}

#pragma mark - Alert view
- (void)alertView:(UIAlertView *)theAlertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [super alertView:theAlertView didDismissWithButtonIndex:buttonIndex];
    self.alertView = nil;
}

#pragma mark - Communication callbacks

- (void)serverErrorReceived:(NSError*)error serverProxy:(id)serverProxy
{
    BOOL showErrorMessage = YES;
    if (serverProxy == self.pollServerProxy) {
        showErrorMessage = NO;
        if (!self.lastScheduleRequestError) {
            retryInterval = 2 * kWaterNowRefreshTimeInterval;
            showErrorMessage = YES;
        }
        self.lastScheduleRequestError = error;
    }
    
    [self handleGeneralSprinklerError:[error localizedDescription] showErrorMessage:showErrorMessage];
    
    if (serverProxy == self.pollServerProxy) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        [self scheduleNextListRefreshRequest:retryInterval];
    
        retryInterval *= 2;
        retryInterval = MIN(retryInterval, kWaterNowMaxRefreshInterval);
    }
}

- (void)serverResponseReceived:(id)data serverProxy:(id)serverProxy
{
    [self handleGeneralSprinklerError:nil showErrorMessage:YES];
    
    if (serverProxy == self.pollServerProxy) {
        self.lastScheduleRequestError = nil;
        
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        self.zones = [self filteredZones:data];
        
        if (serverProxy == self.pollServerProxy) {
            [self scheduleNextListRefreshRequest:kWaterNowRefreshTimeInterval];
        }
    }
    [self.tableView reloadData];
}

- (void)loggedOut
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    [self handleLoggedOutSprinklerError];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.zones count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"WaterZoneListCell";
    WaterZoneListCell *cell = (WaterZoneListCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    WaterNowZone *waterNowZone = [self.zones objectAtIndex:indexPath.row];
    BOOL pending = [Utils isZonePending:waterNowZone];
    BOOL watering = [Utils isZoneWatering:waterNowZone];
    //  BOOL unkownState = (!pending) && (!watering);
    
    cell.delegate = self;
    cell.zone = waterNowZone;
    
    cell.zoneNameLabel.text = waterNowZone.name;
    cell.descriptionLabel.text = waterNowZone.type;
    cell.onOffSwitch.on = watering || pending;
    
    cell.onOffSwitch.onTintColor = pending ? switchOnOrangeColor : (watering ? switchOnGreenColor : [UIColor grayColor]);
    cell.timeLabel.textColor = cell.onOffSwitch.onTintColor;
    
    cell.timeLabel.text = [NSString formattedTime:[[Utils fixedZoneCounter:waterNowZone.counter watering:watering] intValue] usingOnlyDigits:NO];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    WaterNowLevel1VC *waterNowZoneVC = [[WaterNowLevel1VC alloc] init];
    WaterNowZone *waterZone = [self.zones objectAtIndex:indexPath.row];
    waterNowZoneVC.waterZone = waterZone;
    [self.navigationController pushViewController:waterNowZoneVC animated:YES];
}

#pragma mark - Backend

- (NSArray*)filteredZones:(NSArray*)zones
{
    NSMutableArray *rez = [NSMutableArray array];
    for (WaterNowZone *zone in zones) {
        // Skip the Master Valve
        if ([zone.id intValue] != 1) {
            [rez addObject:zone];
        }
    }
    return rez;
}

#pragma mark - Table View Cell callback

- (void)toggleWatering:(BOOL)switchValue onZone:(WaterNowZone*)zone withCounter:(NSNumber*)counter
{
    [self.postServerProxy toggleWatering:switchValue onZone:zone withCounter:counter];
}

#pragma mark - Actions

- (IBAction)next:(id)sender {
    WaterNowLevel1VC *water = [[WaterNowLevel1VC alloc] init];
    [self.navigationController pushViewController:water animated:YES];
}

#pragma mark - Methods

- (void)openDevices {
    DevicesVC *devicesVC = [[DevicesVC alloc] init];
    UINavigationController *navDevices = [[UINavigationController alloc] initWithRootViewController:devicesVC];
    [self presentViewController:navDevices animated:YES completion:nil];
}

#pragma mark - Dealloc

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
