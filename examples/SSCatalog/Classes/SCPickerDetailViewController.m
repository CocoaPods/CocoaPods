//
//  SCPickerDetailViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 10/9/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCPickerDetailViewController.h"
#import "SCPickerDemoViewController.h"

@implementation SCPickerDetailViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Choose";
}


#pragma mark - SSPickerViewController

- (void)loadKeys {
	self.keys = [[NSTimeZone abbreviationDictionary] allKeys];
}


- (NSString *)cellTextForKey:(NSString *)key {
	return  [[NSTimeZone timeZoneWithAbbreviation:key] name];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];

	// Notify the parent view controller of the change
	SCPickerDemoViewController *viewController = (SCPickerDemoViewController *)[self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count] - 2)];
	viewController.selectedAbbreviation = [self.keys objectAtIndex:indexPath.row];

	[self.navigationController popViewControllerAnimated:YES];
}

@end
