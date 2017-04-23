//
//  JSControlLayout.h
//  Controller
//
//  Created by xxxxxx on 01/02/2017.
//  Copyright (c) 2017 xxxxxx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSDPad.h"
#import "JSButton.h"

@interface JSControlLayout : UIView

@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) UIDeviceOrientation orientation;

@property (nonatomic, assign) id <JSDPadDelegate, JSButtonDelegate> delegate;

- (id)initWithLayout:(NSString *)layoutFile delegate:(id <JSDPadDelegate, JSButtonDelegate>)delegate;

@end
