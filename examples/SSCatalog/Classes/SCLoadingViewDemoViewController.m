//
//  SCLoadingViewDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 11/15/10.
//  Copyright 2010 Sam Soffes. All rights reserved.
//

#import "SCLoadingViewDemoViewController.h"

@implementation SCLoadingViewDemoViewController

#pragma mark - Class Methods

+ (NSString *)title {
	return @"Loading View";
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor colorWithRed:0.851f green:0.859f blue:0.882f alpha:1.0f];
	
	CGSize size = self.view.frame.size;
	
	SSLoadingView *loadingView = [[SSLoadingView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
	[self.view addSubview:loadingView];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


@end
