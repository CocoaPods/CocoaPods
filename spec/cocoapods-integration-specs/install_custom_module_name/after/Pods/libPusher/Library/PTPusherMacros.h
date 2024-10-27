//
//  PTPusherMacros.h
//  libPusher
//
//  Created by Luke Redpath on 10/02/2012.
//  Copyright (c) 2012 LJR Software Limited. All rights reserved.
//

#ifndef libPusher_PTPusherMacros_h
#define libPusher_PTPusherMacros_h

#define __PUSHER_DEPRECATED__ __attribute__((deprecated))

#define PT_DEFINE_SHARED_INSTANCE_USING_BLOCK(block) \
static dispatch_once_t pred = 0; \
__strong static id _sharedObject = nil; \
dispatch_once(&pred, ^{ \
_sharedObject = block(); \
}); \
return _sharedObject; \

#endif
