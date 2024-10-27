# Reachability

This is a drop-in replacement for Apples Reachability class. It is ARC compatible, uses the new GCD methods to notify of network interface changes.

In addition to the standard NSNotification it supports the use of Blocks for when the network becomes reachable and unreachable.

Finally you can specify wether or not a WWAN connection is considered "reachable".

## A Simple example
This sample uses Blocks to tell you when the interface state has changed. The blocks will be called on a BACKGROUND THREAD so you need to dispatch UI updates onto the main thread.

	// allocate a reachability object
	Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];

	// set the blocks 
	reach.reachableBlock = ^(Reachability*reach)
	{
		NSLog(@"REACHABLE!");
	};

	reach.unreachableBlock = ^(Reachability*reach)
	{
		NSLog(@"UNREACHABLE!");
	};

	// start the notifier which will cause the reachability object to retain itself!
	[reach startNotifier];

## Another simple example
This sample will use NSNotifications to tell you when the interface has changed, they will be delivered on the MAIN THREAD so you *can* do UI updates from within the function.

In addition it asks the Reachability object to consider the WWAN (3G/EDGE/CDMA) as a non-reachable connection (you might use this if you are writing a video streaming app, for example, to save the users data plan).

	// allocate a reachability object
	Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];

	// tell the reachability that we DONT want to be reachable on 3G/EDGE/CDMA
	reach.reachableOnWWAN = NO;
	
	// here we set up a NSNotification observer. The Reachability that caused the notification
	// is passed in the object parameter
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(reachabilityChanged:) 
												 name:kReachabilityChangedNotification 
											   object:nil];
											
	[reach startNotifier]
	