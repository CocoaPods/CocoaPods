//
//  EmbedReaderAppDelegate.h
//  EmbedReader
//
//  Created by spadix on 5/2/11.
//

#import <UIKit/UIKit.h>

@class EmbedReaderViewController;

@interface EmbedReaderAppDelegate
    : NSObject
    < UIApplicationDelegate >
{
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EmbedReaderViewController *viewController;

@end
