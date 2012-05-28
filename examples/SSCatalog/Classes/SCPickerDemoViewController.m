//
//  SCPickerDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 10/9/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCPickerDemoViewController.h"
#import "SCPickerDetailViewController.h"

@implementation SCPickerDemoViewController

#pragma mark - Accessors

@synthesize selectedAbbreviation = _selectedAbbreviation;


#pragma mark - Class Methods

+ (NSString *)title {
	return @"Settings Picker";
}


#pragma mark - NSObject

- (id)init {
	return self = [super initWithStyle:UITableViewStyleGrouped];
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.selectedAbbreviation = [[NSTimeZone defaultTimeZone] abbreviation];
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cell";

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
	}

	cell.textLabel.text = @"Picker Value";
	cell.detailTextLabel.text = [[NSTimeZone timeZoneWithAbbreviation:self.selectedAbbreviation] name];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	SCPickerDetailViewController *viewController = [[SCPickerDetailViewController alloc] initWithStyle:UITableViewStyleGrouped];
	viewController.selectedKey = self.selectedAbbreviation;
	[self.navigationController pushViewController:viewController animated:YES];
}

@end
