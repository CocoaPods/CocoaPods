**_NOTE: This is the MGSplitViewController example from https://github.com/mattgemmell/MGSplitViewController, but only updated to use CocoaPods. It does not contain the actual source files that make up the library, because those are fetched when running: $pod install_**


MGSplitViewController
=====================

MGSplitViewController is a replacement for UISplitViewController, with various useful enhancements.


Donations
---------

I wrote MGSplitViewController for my own use, but I'm making it available (as usual) for the benefit of the iOS developer community.

If you find it useful, a Paypal donation (or something from my Amazon.co.uk Wishlist) would be very much appreciated. Appropriate links can be found here: <http://mattgemmell.com/source>


Features
--------

Please note that, since split-views are commonly used for "Master-Detail" interfaces, I call the first sub-view the "master" and the second sub-view the "detail".

- By default, MGSplitViewController mimics the appearance and (complete) behaviour of UISplitViewController, including its delegate API. It accepts two UIViewControllers (or subclasses thereof).
- Allows toggling the _visibility of the master view_ in either interface-orientation; i.e. you can have master-detail or detail-only in either landscape and/or portrait orientations (independently, and/or interactively).
- Allows choosing whether the _split orientation_ is vertical (i.e. left/right, like UISplitViewController), or horizontal (master above, and detail below). You can toggle between modes interactively, with animation.
- Allows choosing whether the master view is _before_ (above, or to left of) the detail view, or _after_ it (below, or to the right).
- Allows you to choose (and change) the _position_ of the split, i.e. the relative sizes of the master and detail views.
- Allows you to enable _dragging_ of the split/divider between the master and detail views, with optional constraining via a delegate method.
- Allows you to choose the _width of the split_ between the master and detail views.
- Preset "_divider styles_": one for non-draggable UISplitViewController-like dividers, and one for draggable, thicker style with a grip-strip.
- Allows you to substitute your own divider-view (an MGSplitDividerView subclass), used to draw the split between the master and detail views.


How to use
----------

The "MGSplitViewController.h" header file (and the sample project) should be self-explanatory. It's recommended that you use the project as a reference.


Interface Builder support
-------------------------

At time of writing, MGSplitViewController cannot be quite as elegantly _visually_ configured like UISplitViewController using Interface Builder.

You can, however, (and it is recommended that you do) create an instance of it in a xib, and connect the masterViewController and detailViewController outlets to the required view-controllers.


License and Warranty
--------------------

The license for the code is included with the project; it's basically a BSD license with attribution.

You're welcome to use it in commercial, closed-source, open source, free or any other kind of software, as long as you credit me appropriately.

The MGSplitViewController code comes with no warranty of any kind. I hope it'll be useful to you (it certainly is to me), but I make no guarantees regarding its functionality or otherwise.


Support / Contact / Bugs / Features
-----------------------------------

I can't answer any questions about how to use the code, but I always welcome emails telling me that you're using it, or just saying thanks.

If you create an app which uses the code, I'd also love to hear about it. You can find my contact details on my web site, listed below.

Likewise, if you want to submit a feature request or bug report, feel free to get in touch. Better yet, fork the code and implement the feature/fix yourself, then submit a pull request.

Enjoy the code!


Cheers,  
Matt Legend Gemmell  

Writing: http://mattgemmell.com/  
Contact: http://mattgemmell.com/about  
Twitter: http://twitter.com/mattgemmell  
Hire Me: http://instinctivecode.com/  
