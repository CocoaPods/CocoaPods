//
//  SCSegmentedControlDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 2/14/11.
//  Copyright 2011 Sam Soffes. All rights reserved.
//

#import "SCSegmentedControlDemoViewController.h"

@implementation SCSegmentedControlDemoViewController {
	UISegmentedControl *_systemSegmentedControl;
	SSSegmentedControl *_customSegmentedControl;
}


#pragma mark - Class Methods

+ (NSString *)title {
	return @"Segmented Control";
}


#pragma mark - NSObject

- (void)dealloc {
	[_systemSegmentedControl release];
	[_customSegmentedControl release];
	[super dealloc];
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor colorWithRed:0.851f green:0.859f blue:0.882f alpha:1.0f];
	
	UIFont *labelFont = [UIFont boldSystemFontOfSize:15.0f];
	NSArray *items = [NSArray arrayWithObjects:@"Apples", @"Oranges", [UIImage imageNamed:@"SamLogo.png"], nil];
	
	// System segmented control
	UILabel *systemLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 280.0f, 20.0f)];
	systemLabel.text = @"UISegmentedControl";
	systemLabel.font = labelFont;
	systemLabel.backgroundColor = self.view.backgroundColor;
	systemLabel.shadowColor = [UIColor whiteColor];
	systemLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
	[self.view addSubview:systemLabel];
	[systemLabel release];
	
	_systemSegmentedControl = [[UISegmentedControl alloc] initWithItems:items];
	_systemSegmentedControl.frame = CGRectMake(20.0f, 50.0f, 280.0f, 32.0f);
	_systemSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	_systemSegmentedControl.selectedSegmentIndex = 0;
	[_systemSegmentedControl setEnabled:NO forSegmentAtIndex:1];
	[_systemSegmentedControl addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:_systemSegmentedControl];
	
	// Custom segmented control
	UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 107.0f, 280.0f, 20.0f)];
	customLabel.text = @"SSSegmentedControl";
	customLabel.font = labelFont;
	customLabel.backgroundColor = self.view.backgroundColor;
	customLabel.shadowColor = [UIColor whiteColor];
	customLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
	[self.view addSubview:customLabel];
	[customLabel release];
	
	_customSegmentedControl = [[SSSegmentedControl alloc] initWithItems:items];
	_customSegmentedControl.frame = CGRectMake(20.0f, 137.0f, 280.0f, 32.0f);
	_customSegmentedControl.selectedSegmentIndex = 0;
	[_customSegmentedControl setEnabled:NO forSegmentAtIndex:1];
	[_customSegmentedControl addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:_customSegmentedControl];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - Actions

- (void)valueChanged:(id)sender {
	NSLog(@"Value changed to %i", [sender selectedSegmentIndex]);
	
	if (sender == _systemSegmentedControl) {
		_customSegmentedControl.selectedSegmentIndex = _systemSegmentedControl.selectedSegmentIndex;
	} else {
		_systemSegmentedControl.selectedSegmentIndex = _customSegmentedControl.selectedSegmentIndex;
	}
}

@end
