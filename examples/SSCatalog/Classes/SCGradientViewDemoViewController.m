//
//  SCGradientViewDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 10/27/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCGradientViewDemoViewController.h"

@implementation SCGradientViewDemoViewController {
	BOOL _blue;
	SSGradientView *_gradientView;
}


#pragma mark - Class Methods

+ (NSString *)title {
	return @"Gradient View";
}


#pragma mark - NSObject

- (void)dealloc {
	[_gradientView release];
	[super dealloc];
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
	self.view.backgroundColor = [UIColor whiteColor];
	
	// Gradient view
	_gradientView = [[SSGradientView alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 280.0f, 280.0f)];
	_gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_gradientView.topBorderColor = [UIColor colorWithRed:0.558f green:0.599f blue:0.643f alpha:1.0f];
	_gradientView.topInsetColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
	_gradientView.colors = [NSArray arrayWithObjects:
							[UIColor colorWithRed:0.676f green:0.722f blue:0.765f alpha:1.0f],
							[UIColor colorWithRed:0.514f green:0.568f blue:0.617f alpha:1.0f],
							nil];
	_gradientView.bottomBorderColor = [UIColor colorWithRed:0.428f green:0.479f blue:0.520f alpha:1.0f];
	[self.view addSubview:_gradientView];
	
	// Change color button
	UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	button.frame = CGRectMake(20.0f, 320.0f, 280.0f, 37.0f);
	[button setTitle:@"Change Color" forState:UIControlStateNormal];
	[button addTarget:self action:@selector(changeColor:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:button];
	
	// Scale slider
	UISlider *scaleSlider = [[UISlider alloc] initWithFrame:CGRectMake(20.0f, 377.0f, 280.0f, 20.0f)];
	scaleSlider.value = 1.0f;
	scaleSlider.minimumValue = 0.0f;
	scaleSlider.maximumValue = 1.0f;
	[scaleSlider addTarget:self action:@selector(updateScale:) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:scaleSlider];
	[scaleSlider release];
	
	_blue = YES;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - Actions

- (void)changeColor:(id)sender {
	if (_blue) {
		_gradientView.colors = [NSArray arrayWithObjects:
								[UIColor redColor],
								[UIColor orangeColor],
								nil];
	} else {
		_gradientView.colors = [NSArray arrayWithObjects:
								[UIColor colorWithRed:0.676f green:0.722f blue:0.765f alpha:1.0f],
								[UIColor colorWithRed:0.514f green:0.568f blue:0.617f alpha:1.0f],
								nil];
	}
	
	_blue = !_blue;
}


- (void)updateScale:(id)sender {
	_gradientView.gradientScale = [(UISlider *)sender value];
}

@end
