//
//  SCSwitchDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 11/19/10.
//  Copyright 2010 Sam Soffes. All rights reserved.
//

#import "SCSwitchDemoViewController.h"

@implementation SCSwitchDemoViewController

#pragma mark - Class Methods

+ (NSString *)title {
	return @"Switch";
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor colorWithRed:0.851f green:0.859f blue:0.882f alpha:1.0f];
	
	UIFont *labelFont = [UIFont boldSystemFontOfSize:15.0f];
	
	// System switch
	UILabel *systemLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 280.0f, 20.0f)];
	systemLabel.text = @"Standard UISwitch";
	systemLabel.font = labelFont;
	systemLabel.backgroundColor = self.view.backgroundColor;
	systemLabel.shadowColor = [UIColor whiteColor];
	systemLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
	[self.view addSubview:systemLabel];
	[systemLabel release];
	
	UISwitch *systemOffSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20.0f, 50.0f, 94.0f, 27.0f)];
	[self.view addSubview:systemOffSwitch];
	[systemOffSwitch release];
	
	UISwitch *systemOnSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(134.0f, 50.0f, 94.0f, 27.0f)];
	systemOnSwitch.on = YES;
	[self.view addSubview:systemOnSwitch];
	[systemOnSwitch release];
	
	// Default style
	UILabel *defaultLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 107.0f, 280.0f, 20.0f)];
	defaultLabel.text = @"SSSwitchStyleDefault";
	defaultLabel.font = labelFont;
	defaultLabel.backgroundColor = self.view.backgroundColor;
	defaultLabel.shadowColor = [UIColor whiteColor];
	defaultLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
	[self.view addSubview:defaultLabel];
	[defaultLabel release];
	
	SSSwitch *defaultOffSwitch = [[SSSwitch alloc] initWithFrame:CGRectMake(20.0f, 137.0f, 94.0f, 27.0f)];
	[self.view addSubview:defaultOffSwitch];
	[defaultOffSwitch release];
	
	SSSwitch *defaultOnSwitch = [[SSSwitch alloc] initWithFrame:CGRectMake(134.0f, 137.0f, 94.0f, 27.0f)];
	defaultOnSwitch.on = YES;
	[self.view addSubview:defaultOnSwitch];
	[defaultOnSwitch release];
	
	// Airplane mode style
	UILabel *airplaneLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 194.0f, 280.0f, 20.0f)];
	airplaneLabel.text = @"SSSwitchStyleAirplane";
	airplaneLabel.font = labelFont;
	airplaneLabel.backgroundColor = self.view.backgroundColor;
	airplaneLabel.shadowColor = [UIColor whiteColor];
	airplaneLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
	[self.view addSubview:airplaneLabel];
	[airplaneLabel release];
	
	SSSwitch *airplaneOffSwitch = [[SSSwitch alloc] initWithFrame:CGRectMake(20.0f, 224.0f, 94.0f, 27.0f)];
	airplaneOffSwitch.style = SSSwitchStyleAirplane;
	[self.view addSubview:airplaneOffSwitch];
	[airplaneOffSwitch release];
	
	SSSwitch *airplaneOnSwitch = [[SSSwitch alloc] initWithFrame:CGRectMake(134.0f, 224.0f, 94.0f, 27.0f)];
	airplaneOnSwitch.style = SSSwitchStyleAirplane;
	airplaneOnSwitch.on = YES;
	[self.view addSubview:airplaneOnSwitch];
	[airplaneOnSwitch release];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}

@end
