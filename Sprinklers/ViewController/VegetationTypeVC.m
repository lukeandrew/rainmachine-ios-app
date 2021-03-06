//
//  VegetationTypeVC.m
//  Sprinklers
//
//  Created by Fabian Matyas on 04/03/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "VegetationTypeVC.h"
#import "Constants.h"
#import "ZoneVC.h"
#import "+UIDevice.h"
#import "ServerProxy.h"

@interface VegetationTypeVC ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation VegetationTypeVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view.
    [_tableView registerNib:[UINib nibWithNibName:@"SimpleCell" bundle:nil] forCellReuseIdentifier:@"SimpleCell"];
    
    self.title = @"Vegetation type";
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.parent vegetationTypeVCWillDissapear:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SimpleCell";
    UITableViewCell *cell = (UITableViewCell*)[self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = [ServerProxy usesAPI3] ? kVegetationType[indexPath.row + 2] : kVegetationTypeAPI4[indexPath.row + 1];
    if ([[UIDevice currentDevice] iOSGreaterThan:7]) {
        cell.tintColor = [UIColor colorWithRed:kSprinklerBlueColor[0] green:kSprinklerBlueColor[1] blue:kSprinklerBlueColor[2] alpha:1];
    }
    if ([ServerProxy usesAPI3]) {
        cell.accessoryType = (indexPath.row == (_vegetationType - 2)) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.accessoryType = (indexPath.row == (_vegetationType - 1)) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:_vegetationType - ([ServerProxy usesAPI3] ? 2 : 1) inSection:indexPath.section];
    UITableViewCell *oldCell = [self.tableView cellForRowAtIndexPath:oldIndexPath];
    oldCell.accessoryType = UITableViewCellAccessoryNone;
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    self.vegetationType = ([ServerProxy usesAPI3] ? 2 : 1) + (int)indexPath.row;
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
