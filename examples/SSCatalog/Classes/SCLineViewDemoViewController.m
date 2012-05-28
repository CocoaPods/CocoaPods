//
//  SCLineViewDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 4/19/10.
//  Copyright 2010 Sam Soffes, Inc. All rights reserved.
//

#import "SCLineViewDemoViewController.h"

@implementation SCLineViewDemoViewController

#pragma mark - Class Methods

+ (NSString *)title {
	return @"Line View";
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor colorWithRed:0.851f green:0.859f blue:0.882f alpha:1.0f];
	
	SSLineView *lineView1 = [[SSLineView alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 280.0f, 2.0f)];
	[self.view addSubview:lineView1];
	
	SSLineView *lineView2 = [[SSLineView alloc] initWithFrame:CGRectMake(20.0f, 42.0f, 280.0f, 2.0f)];
	lineView2.lineColor = [UIColor blueColor];
	[self.view addSubview:lineView2];
	
	SSLineView *lineView3 = [[SSLineView alloc] initWithFrame:CGRectMake(20.0f, 64.0f, 280.0f, 2.0f)];
	lineView3.lineColor = [UIColor orangeColor];
	lineView3.dashLengths = [NSArray arrayWithObjects:[NSNumber numberWithFloat:5.0f], [NSNumber numberWithFloat:2.0f], nil];
	[self.view addSubview:lineView3];
	
	SSLineView *lineView4 = [[SSLineView alloc] initWithFrame:CGRectMake(20.0f, 86.0f, 280.0f, 2.0f)];
	lineView4.lineColor = [UIColor greenColor];
	lineView4.dashLengths = [NSArray arrayWithObjects:[NSNumber numberWithFloat:2.0f], [NSNumber numberWithFloat:2.0f], nil];
	[self.view addSubview:lineView4];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}

@end
