//
//  SCBadgeTableViewCellDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 01/29/11.
//  Copyright 2011 Sam Soffes, Inc. All rights reserved.
//

#import "SCBadgeTableViewCellDemoViewController.h"

@implementation SCBadgeTableViewCellDemoViewController

#pragma mark - Class Methods

+ (NSString *)title {
	return @"Badge Table View Cell";
}


#pragma mark - NSObject

- (id)init {
	return self = [super initWithStyle:UITableViewStyleGrouped];
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
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
	return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (section == 0) ? 4 : 12;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cell";
	
	SSBadgeTableViewCell *cell = (SSBadgeTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[SSBadgeTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier] autorelease];
	}
	
	if (indexPath.section == 0) {
		switch (indexPath.row) {
			case 0: {
				cell.textLabel.text = @"Default Badge View";
				cell.badgeView.textLabel.text = @"0";
				cell.badgeView.badgeColor = [SSBadgeView defaultBadgeColor];
				break;
			}
			
			case 1: {
				cell.textLabel.text = @"Unread Count";
				cell.badgeView.textLabel.text = @"3";
				cell.badgeView.badgeColor = [UIColor colorWithRed:0.969f green:0.082f blue:0.078f alpha:1.0f];
				break;
			}
			
			case 2: {
				cell.textLabel.text = @"Text Badge";
				cell.badgeView.textLabel.text = @"New";
				cell.badgeView.badgeColor = [UIColor colorWithRed:0.388f green:0.686f blue:0.239f alpha:1.0f];
				break;
			}
			
			case 3: {
				cell.textLabel.text = @"Nil value";
				cell.badgeView.textLabel.text = nil;
				cell.badgeView.badgeColor = [SSBadgeView defaultBadgeColor];
				break;
			}
		}
	} else {
		NSNumber *number = [NSNumber numberWithInteger:indexPath.row * 256];
		cell.textLabel.text = [[NSNumberFormatter localizedStringFromNumber:number numberStyle:NSNumberFormatterSpellOutStyle] capitalizedString];
		cell.badgeView.textLabel.text = [NSNumberFormatter localizedStringFromNumber:number numberStyle:NSNumberFormatterDecimalStyle];
		cell.badgeView.badgeColor = [SSBadgeView defaultBadgeColor];
	}
	
	return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
