    //
//  SCPieProgressViewDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 4/22/10.
//  Copyright 2010 Sam Soffes, Inc. All rights reserved.
//

#import "SCPieProgressViewDemoViewController.h"

@implementation SCPieProgressViewDemoViewController {
	SSPieProgressView *_progressView7;
	NSTimer *_timer;
}


#pragma mark - Class Methods

+ (NSString *)title {
	return @"Pie Progress View";
}


#pragma mark - NSObject

- (void)dealloc {
	[_timer invalidate];
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor colorWithRed:0.851f green:0.859f blue:0.882f alpha:1.0f];
	
	SSPieProgressView *progressView1 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 55.0f, 55.0f)];
	progressView1.progress = 0.25;
	[self.view addSubview:progressView1];
	
	SSPieProgressView *progressView2 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(95.0f, 20.0f, 55.0f, 55.0f)];
	progressView2.progress = 0.50;
	[self.view addSubview:progressView2];
	
	SSPieProgressView *progressView3 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(170.0f, 20.0f, 55.0f, 55.0f)];
	progressView3.progress = 0.75;
	[self.view addSubview:progressView3];
	
	SSPieProgressView *progressView4 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(245.0f, 20.0f, 55.0f, 55.0f)];
	progressView4.progress = 1.0;
	[self.view addSubview:progressView4];
	
	SSPieProgressView *progressView5 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(20.0f, 95.0f, 130.0f, 130.0f)];
	progressView5.progress = 0.33;
	[self.view addSubview:progressView5];
	
	SSPieProgressView *progressView6 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(170.0f, 95.0f, 130.0f, 130.0f)];
	progressView6.progress = 0.66;
	[self.view addSubview:progressView6];
	
	_progressView7 = [[SSPieProgressView alloc] initWithFrame:CGRectMake(95.0f, 245.0f, 130.0f, 130.0f)];
	[self.view addSubview:_progressView7];
	
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(incrementProgress:) userInfo:nil repeats:YES];
}


- (void)viewDidUnload {
	[super viewDidUnload];
	[_timer invalidate];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - Timer

- (void)incrementProgress:(NSTimer *)timer {
	_progressView7.progress = _progressView7.progress + 0.01;
	if (_progressView7.progress == 1.0f) {
		_progressView7.progress = 0.0;
	}
}

@end
