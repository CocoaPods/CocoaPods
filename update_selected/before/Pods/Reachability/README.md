# Reachability

This is a drop-in replacement for Apples Reachability class. It is ARC compatible, uses the new GCD methods to notify of network interface changes.

In addition to the standard NSNotification it supports the use of Blocks for when the network becomes reachable and unreachable.

Finally you can specify wether or not a WWAN connection is considered "reachable".

## A Simple example

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

