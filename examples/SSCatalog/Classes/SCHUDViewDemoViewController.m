//
//  SCHUDViewDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 11/18/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCHUDViewDemoViewController.h"

@implementation SCHUDViewDemoViewController {
	SSHUDView *_hud;
}


#pragma mark - Class Methods

+ (NSString *)title {
	return @"HUD View";
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor whiteColor];
	
	// Show HUD
	_hud = [[SSHUDView alloc] initWithTitle:@"Loading..."];
//	_hud.hudSize = CGSizeMake(60.0f, 60.0f);
//	_hud.textLabelHidden = YES;
//	_hud.hidesVignette = YES;
	[_hud show];
	
	// After 2 seconds, complete action
	[self performSelector:@selector(complete:) withObject:nil afterDelay:2.0];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - Actions

- (void)complete:(id)sender {
	[_hud completeWithTitle:@"Finished"];
	[self performSelector:@selector(pop:) withObject:nil afterDelay:0.7];
}


- (void)pop:(id)sender {
	[_hud dismiss];
	[self.navigationController popViewControllerAnimated:YES];
}

@end
