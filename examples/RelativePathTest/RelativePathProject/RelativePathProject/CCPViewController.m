//
//  CCPViewController.m
//  RelativePathProject
//
//  Created by Ben Scheirman on 3/8/12.
//  Copyright (c) 2012 ChaiONE. All rights reserved.
//

#import "CCPViewController.h"

@interface CCPViewController ()

@end

@implementation CCPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end
