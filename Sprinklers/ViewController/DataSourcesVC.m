//
//  DataSourcesVC.m
//  Sprinklers
//
//  Created by Istvan Sipos on 27/02/15.
//  Copyright (c) 2015 Tremend. All rights reserved.
//

#import "DataSourcesVC.h"
#import "DataSourcesParserVC.h"
#import "SettingsVC.h"
#import "ServerProxy.h"
#import "Utils.h"
#import "Parser.h"
#import "ParserCell.h"
#import "MBProgressHUD.h"

#pragma mark -

@interface DataSourcesVC ()

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) ServerProxy *requestParsersServerProxy;
@property (nonatomic, strong) ServerProxy *activateParserServerProxy;
@property (nonatomic, strong) NSArray *parsers;

- (void)reload;
- (void)cancel;
- (void)requestParsers;
- (void)activateParser:(Parser*)parser activate:(BOOL)activate;

@property (nonatomic, readonly) BOOL loading;
@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, readonly) NSArray *includedParsers;

- (void)refreshProgressHUD;
- (NSArray*)filteredParsersFromParsers:(NSArray*)parsers;

@end

#pragma mark -

@implementation DataSourcesVC

#pragma mark - Init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Data Sources";
    [self.tableView registerNib:[UINib nibWithNibName:@"ParserCell" bundle:nil] forCellReuseIdentifier:@"ParserCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self reload];
    [self.tableView reloadData];
    [self refreshProgressHUD];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.unsavedParser) {
        DataSourcesParserVC *dataSourcesParserVC = [[DataSourcesParserVC alloc] init];
        dataSourcesParserVC.parser = self.parser;
        dataSourcesParserVC.unsavedParser = self.unsavedParser;
        dataSourcesParserVC.parent = self;
        dataSourcesParserVC.showInitialUnsavedAlert = YES;
        
        self.parser = nil;
        self.unsavedParser = nil;
        
        [self.navigationController pushViewController:dataSourcesParserVC animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self cancel];
    [self refreshProgressHUD];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSArray*)includedParsers {
    // return nil to include all parsers
    return @[@"noaa parser", @"metno parser"];
}

#pragma mark - Helper methods

- (BOOL)loading {
    return (self.requestParsersServerProxy != nil || self.activateParserServerProxy != nil);
}

- (void)reload {
    [self requestParsers];
    [self refreshProgressHUD];
}

- (void)cancel {
    [self.requestParsersServerProxy cancelAllOperations], self.requestParsersServerProxy = nil;
    [self.activateParserServerProxy cancelAllOperations], self.activateParserServerProxy = nil;
}

- (void)requestParsers {
    self.requestParsersServerProxy = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:YES];
    [self.requestParsersServerProxy requestParsers];
}

- (void)activateParser:(Parser*)parser activate:(BOOL)activate {
    self.activateParserServerProxy = [[ServerProxy alloc] initWithSprinkler:[Utils currentSprinkler] delegate:self jsonRequest:YES];
    [self.activateParserServerProxy activateParser:parser activate:activate];
}

- (void)refreshProgressHUD {
    BOOL shouldShowProgressHUD = self.loading;
    if (shouldShowProgressHUD && !self.hud) self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    else if (!shouldShowProgressHUD && self.hud) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        self.hud = nil;
    }
}

- (NSArray*)filteredParsersFromParsers:(NSArray*)parsers {
    if (!self.includedParsers) return parsers;
    
    NSMutableArray *filteredParsers = [NSMutableArray new];
    for (Parser *parser in parsers) {
        if (![self.includedParsers containsObject:parser.name.lowercaseString]) continue;
        [filteredParsers addObject:parser];
    }
    
    return filteredParsers;
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return self.parsers.count;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell*)cell forRowAtIndexPath:(NSIndexPath*)indexPath {
    cell.backgroundColor = [UIColor whiteColor];
}

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    return 56.0;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString *CellIdentifier = @"ParserCell";

    Parser *parser = self.parsers[indexPath.row];
    ParserCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    cell.parser = parser;
    cell.delegate = self;
    cell.accessoryType = (parser.params ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone);
    cell.selectionStyle = (parser.params ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone);
    
    return cell;
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Parser *parser = self.parsers[indexPath.row];
    if (parser.params) {
        DataSourcesParserVC *dataSourcesParserVC = [[DataSourcesParserVC alloc] init];
        dataSourcesParserVC.parser = parser;
        dataSourcesParserVC.parent = self;
        
        [self.navigationController pushViewController:dataSourcesParserVC animated:YES];
    }
}

#pragma mark - Parser cell delegate

- (void)parserCell:(ParserCell*)parserCell activateParser:(BOOL)activateParser {
    [self activateParser:parserCell.parser activate:activateParser];
    [self refreshProgressHUD];
}

#pragma mark - ProxyService delegate

- (void)serverResponseReceived:(id)data serverProxy:(id)serverProxy userInfo:(id)userInfo {
    if (serverProxy == self.requestParsersServerProxy) {
        self.parsers = [self filteredParsersFromParsers:data];
        self.requestParsersServerProxy = nil;
    }
    else if (serverProxy == self.activateParserServerProxy) {
        self.activateParserServerProxy = nil;
    }
    
    [self.tableView reloadData];
    [self refreshProgressHUD];
}

- (void)serverErrorReceived:(NSError *)error serverProxy:(id)serverProxy operation:(AFHTTPRequestOperation *)operation userInfo:(id)userInfo {
    [self.parent handleSprinklerNetworkError:error operation:operation showErrorMessage:YES];
    
    if (serverProxy == self.requestParsersServerProxy) self.requestParsersServerProxy = nil;
    else if (serverProxy == self.activateParserServerProxy) self.activateParserServerProxy = nil;
    
    [self.tableView reloadData];
    [self refreshProgressHUD];
}

- (void)loggedOut {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self handleLoggedOutSprinklerError];
}

@end
