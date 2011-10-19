//
//  SSRatingDemoViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 2/3/11.
//  Copyright 2011 Sam Soffes. All rights reserved.
//

#import "SSRatingDemoViewController.h"

@implementation SSRatingDemoViewController

#pragma mark - Class Methods

+ (NSString *)title {
	return @"Rating Picker";
}


#pragma mark - UIViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [[self class] title];
}

@end
