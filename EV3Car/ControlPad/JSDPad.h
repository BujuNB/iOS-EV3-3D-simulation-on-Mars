//
//  JSDPad.h
//  Controller
//
//  Created by xxxxxx on 01/02/2017.
//  Copyright (c) 2017 xxxxxx. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, JSDPadDirection)
{
	JSDPadDirectionUpLeft = 1,
	JSDPadDirectionUp,
	JSDPadDirectionUpRight,
	JSDPadDirectionLeft,
	JSDPadDirectionNone,
	JSDPadDirectionRight,
	JSDPadDirectionDownLeft,
	JSDPadDirectionDown,
	JSDPadDirectionDownRight
};

@class JSDPad;

@protocol JSDPadDelegate <NSObject>

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction;
- (void)dPadDidReleaseDirection:(JSDPad *)dPad;

@end

@interface JSDPad : UIView

@property (nonatomic, weak) IBOutlet id <JSDPadDelegate> delegate;

- (JSDPadDirection)currentDirection;

@end
