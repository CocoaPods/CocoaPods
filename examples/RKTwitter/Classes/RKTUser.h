//
//  RKTUser.h
//  RKTwitter
//
//  Created by Blake Watters on 9/5/10.
//  Copyright (c) 2009-2012 RestKit. All rights reserved.
//

@interface RKTUser : NSObject {
    NSNumber* _userID;
    NSString* _name;
    NSString* _screenName;
}

@property (nonatomic, retain) NSNumber* userID;
@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) NSString* screenName;

@end
