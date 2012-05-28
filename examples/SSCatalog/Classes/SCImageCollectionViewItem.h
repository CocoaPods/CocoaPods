//
//  SCImageCollectionViewItem.h
//  SSCatalog
//
//  Created by Sam Soffes on 5/3/11.
//  Copyright 2011 Sam Soffes. All rights reserved.
//

@interface SCImageCollectionViewItem : SSCollectionViewItem

@property (nonatomic, strong) NSURL *imageURL;

- (id)initWithReuseIdentifier:(NSString *)aReuseIdentifier;

@end
