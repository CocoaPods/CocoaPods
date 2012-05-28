//
//  SCRootViewController.m
//  SSCatalog
//
//  Created by Sam Soffes on 10/9/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCRootViewController.h"
#import "SCPickerDemoViewController.h"
#import "SCGradientViewDemoViewController.h"

static NSString *const kTitleKey = @"title";
static NSString *const kClassesKey =  @"classes";

@interface UIViewController (SCRootViewControllerAdditions)
+ (id)setup;
@end

@implementation SCRootViewController {
	NSArray *_viewControllers;
}


#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = @"SSCatalog";

    _viewControllers = [[NSArray alloc] initWithObjects:
						[NSDictionary dictionaryWithObjectsAndKeys:
						 [NSArray arrayWithObjects:
						  @"SCBadgeTableViewCellDemoViewController",
						  @"SCCollectionViewDemoViewController",
						  @"SCGradientViewDemoViewController",
						  @"SCHUDViewDemoViewController",
						  @"SCLineViewDemoViewController",
						  @"SCLoadingViewDemoViewController",
						  @"SCPieProgressViewDemoViewController",
						  nil], kClassesKey,
						 @"Views", kTitleKey,
						 nil],
						[NSDictionary dictionaryWithObjectsAndKeys:
						 [NSArray arrayWithObjects:
						  @"SCAddressBarDemoViewController",
						  nil], kClassesKey,
						 @"Controls", kTitleKey,
						 nil],
						[NSDictionary dictionaryWithObjectsAndKeys:
						 [NSArray arrayWithObjects:
						  @"SCPickerDemoViewController",
						  @"SSRatingDemoViewController",
						  nil], kClassesKey,
						 @"View Controllers", kTitleKey,
						 nil],
						nil];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
	}
	return YES;
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_viewControllers count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[_viewControllers objectAtIndex:section] objectForKey:kClassesKey] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];    }
	
	Class klass = [[NSBundle mainBundle] classNamed:[[[_viewControllers objectAtIndex:indexPath.section] objectForKey:kClassesKey] objectAtIndex:indexPath.row]];
		
	cell.textLabel.text = [klass title];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [[_viewControllers objectAtIndex:section] objectForKey:kTitleKey];
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	Class klass = [[NSBundle mainBundle] classNamed:[[[_viewControllers objectAtIndex:indexPath.section] objectForKey:kClassesKey] objectAtIndex:indexPath.row]];
	UIViewController *viewController = [[klass alloc] init];
	[self.navigationController pushViewController:viewController animated:YES];
}

@end
