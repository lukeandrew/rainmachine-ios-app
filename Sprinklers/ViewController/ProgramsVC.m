//
//  ProgramsVC.m
//  Sprinklers
//
//  Created by Daniel Cristolovean on 05/01/14.
//  Copyright (c) 2014 Tremend. All rights reserved.
//

#import "ProgramsVC.h"
#import "Constants.h"
#import "ServerProxy.h"
#import "Program.h"
#import "MBProgressHUD.h"
#import "Additions.h"
#import "Utils.h"
#import "SettingsVC.h"
#import "ProgramVC.h"
#import "ProgramListCell.h"
#import "AddNewCell.h"
#import "ServerResponse.h"

@interface ProgramsVC () {
    MBProgressHUD *hud;
    UIBarButtonItem *editButton;
}

@property (strong, nonatomic) ServerProxy *serverProxy;
@property (strong, nonatomic) ServerProxy *postDeleteServerProxy;
@property (strong, nonatomic) Program *unsavedProgram;
@property (assign, nonatomic) int unsavedProgramIndex;

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ProgramsVC

#pragma mark - Init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Programs";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [_tableView registerNib:[UINib nibWithNibName:@"ProgramListCell" bundle:nil] forCellReuseIdentifier:@"ProgramListCell"];
    [_tableView registerNib:[UINib nibWithNibName:@"AddNewCell" bundle:nil] forCellReuseIdentifier:@"AddNewCell"];
    
    // This will remove extra separators from tableview
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    editButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(edit)];
    self.navigationItem.rightBarButtonItem = editButton;
    
    self.serverProxy = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:NO];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self requestPrograms];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.unsavedProgram) {
        [self pushVCForProgram:self.unsavedProgram withIndex:self.unsavedProgramIndex showInitialUnsavedAlert:YES];
        self.unsavedProgram = nil;
    }
    
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.tableView setEditing:NO];
    [editButton setTitle:@"Edit"];
}

#pragma mark - Methods

- (int)programsCount
{
    if ([ServerProxy usesAPI3]) {
        return (int)(self.programs.count) - 1;
    }
    
    return (int)(self.programs.count);
}

- (void)requestPrograms
{
    [self startHud:nil];
    [self.serverProxy requestPrograms];
}

- (void)startHud:(NSString *)text {
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = text;
}

- (void)edit {
    [self.tableView setEditing:!_tableView.editing animated:YES];
    if (self.tableView.isEditing) {
        [editButton setTitle:@"Done"];
    } else {
        [editButton setTitle:@"Edit"];
    }
}

#pragma mark - ProxyService delegate

- (void)serverResponseReceived:(id)data serverProxy:(id)serverProxy userInfo:(id)userInfo {
    if (serverProxy == self.postDeleteServerProxy) {
        self.postDeleteServerProxy = nil;
        NSString *errorMessage = nil;
        if ([ServerProxy usesAPI3]) {
            ServerResponse *response = [data objectForKey:@"serverResponse"];
            if ([response.status isEqualToString:@"err"]) {
                errorMessage = response.message;
            }
        }
        if (errorMessage) {
            [self.parent handleSprinklerGeneralError:errorMessage showErrorMessage:YES];
        } else {
            NSNumber *delProgramId = [data objectForKey:@"pid"];
            [self programDeleted:delProgramId];
        }
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } else {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        self.programs = [data mutableCopy];
    }
    
    [_tableView reloadData];
}

- (void)serverErrorReceived:(NSError *)error serverProxy:(id)serverProxy operation:(AFHTTPRequestOperation *)operation userInfo:(id)userInfo {
    [MBProgressHUD hideHUDForView:self.view animated:YES];

    [self.parent handleSprinklerNetworkError:error operation:operation showErrorMessage:YES];

//    if (serverProxy == self.postDeleteServerProxy) {
//        [self requestPrograms];
//    }
}

- (void)programDeleted:(NSNumber*)programId {
    for (int i = 0; i < [self programsCount] ; i++) {
        if (((Program *)self.programs[i]).programId == [programId intValue]) {
            [self.programs removeObject:self.programs[i]];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
            break;
        }
    }
}

- (void)loggedOut {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
//    [self handleLoggedOutSprinklerError];
    [self.parent handleLoggedOutSprinklerError];
}

#pragma mark - UITableView delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;//tableView.editing ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 1) return 1;
    return [self programsCount];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Program *program = self.programs[indexPath.row];
        [self startHud:nil];
        self.postDeleteServerProxy = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:NO];
        [self.postDeleteServerProxy deleteProgram:program.programId];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor whiteColor];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return 56;
    }
    
    return 44;
}

//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
//    if (section == [self numberOfSectionsInTableView:tableView] - 1) {
//        return 20.0f;
//    }
//    
//    return 0;
//}
//
//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 35)];
//    headerView.backgroundColor = [UIColor colorWithRed:229.0f / 255.0f green:229.0f / 255.0f blue:229.0f / 255.0f alpha:1.0f];
//    
//    return headerView;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
//    return 20.0f;
//}
//
//- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
//    if (section == [self numberOfSectionsInTableView:tableView] - 1) {
//        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 35)];
//        headerView.backgroundColor = [UIColor colorWithRed:229.0f / 255.0f green:229.0f / 255.0f blue:229.0f / 255.0f alpha:1.0f];
//        return headerView;
//    }
//    
//    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
//    return view;
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        static NSString *CellIdentifier = @"ProgramListCell";
        ProgramListCell *cell = (ProgramListCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        
        Program *program = self.programs[indexPath.row];
        cell.theTextLabel.text = program.name;
        cell.activeStateLabel.text = program.active ? @"" : @"Inactive";

        NSNumber *time_format = ([Utils isTime24HourFormat]) ? @24 : @12;
        NSDateFormatter *formatter = [Utils sprinklerDateFormatterForTimeFormat:time_format seconds:NO forceOnlyTimePart:YES forceOnlyDatePart:NO];
        
        NSString *startHourAndMinute =  [formatter stringFromDate:program.startTime];
        if (!startHourAndMinute) {
            startHourAndMinute = @"";
        } else {
            startHourAndMinute = [@"at " stringByAppendingString:startHourAndMinute];
        }
        
        if ([program.weekdays isEqualToString:@"D"]) {
            cell.theDetailTextLabel.text = [NSString stringWithFormat:@"Daily %@", startHourAndMinute];
        }
        if ([program.weekdays isEqualToString:@"ODD"]) {
            cell.theDetailTextLabel.text = [NSString stringWithFormat:@"Odd days %@", startHourAndMinute];
        }
        if ([program.weekdays containsString:@"INT"]) {
            int nrDays;
            sscanf([program.weekdays UTF8String], "INT %d", &nrDays);
            cell.theDetailTextLabel.text = [NSString stringWithFormat:@"Every %d days %@", nrDays, startHourAndMinute];
        }
        if ([program.weekdays isEqualToString:@"EVD"]) {
            cell.theDetailTextLabel.text = [NSString stringWithFormat:@"Even days %@", startHourAndMinute];
        }
        if ([program.weekdays containsString:@","]) {
            NSString *daysString = [Utils daysStringFromWeekdaysFrequency:program.weekdays];
            if (daysString) {
                cell.theDetailTextLabel.text = [NSString stringWithFormat:@"%@ %@", daysString, startHourAndMinute];
            } else {
                cell.theDetailTextLabel.text = @"";
            }
        }
        
        if ([[UIDevice currentDevice] iOSGreaterThan:7]) {
            cell.theDetailTextLabel.textColor = [UIColor lightGrayColor];
        }
        
        return cell;
    }
    
    if (indexPath.section == 1) {
        AddNewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddNewCell" forIndexPath:indexPath];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        [cell.plusLabel setCustomRMFontWithCode:icon_Add size:24];

        cell.titleLabel.text = @"Add New Program";

        [cell.plusLabel setTextColor:[UIColor colorWithRed:kWateringGreenButtonColor[0] green:kWateringGreenButtonColor[1] blue:kWateringGreenButtonColor[2] alpha:1]];
        [cell.titleLabel setTextColor:[UIColor colorWithRed:kWateringGreenButtonColor[0] green:kWateringGreenButtonColor[1] blue:kWateringGreenButtonColor[2] alpha:1]];
        
        return cell;
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [self pushVCForProgram:self.programs[indexPath.row] withIndex:(int)indexPath.row showInitialUnsavedAlert:NO];
    } else {
        [self pushVCForProgram:nil withIndex:-1 showInitialUnsavedAlert:NO];
    }
}

- (void)pushVCForProgram:(Program*)p withIndex:(int)i showInitialUnsavedAlert:(BOOL)showInitialUnsavedAlert
{
    ProgramVC *dailyProgramVC = [[ProgramVC alloc] init];
    dailyProgramVC.program = p;
    if (showInitialUnsavedAlert) {
        if (i != -1) {
            dailyProgramVC.programCopyBeforeSave = self.programs[i];
        }
    }
    dailyProgramVC.parent = self;
    dailyProgramVC.programIndex = i;
    dailyProgramVC.showInitialUnsavedAlert = showInitialUnsavedAlert;
    [self.navigationController pushViewController:dailyProgramVC animated:!showInitialUnsavedAlert];
}

- (void)setProgram:(Program*)p withIndex:(int)i
{
    if (i >= 0) {
        [self.programs replaceObjectAtIndex:i withObject:p];
    }
}

- (void)setUnsavedProgram:(Program*)program withIndex:(int)i
{
    self.unsavedProgram = program;
    self.unsavedProgramIndex = i;
}

- (int)serverTimeFormat
{
    if ([self.programs count] > 0) {
        Program *p = self.programs[0];
        return p.timeFormat;
    }
    
    // As default return the AM/PM time format. It's more natural for USA people.
    return 1;
}

@end
