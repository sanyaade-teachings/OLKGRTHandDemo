/******************************************************************************\
* Copyright (C) 2012-2013 Leap Motion, Inc. All rights reserved.               *
* Leap Motion proprietary and confidential. Not for distribution.              *
* Use subject to the terms of the Leap Motion SDK Agreement available at       *
* https://developer.leapmotion.com/sdk_agreement, or another agreement         *
* between Leap Motion and you, your company or other organization.             *
\******************************************************************************/

#import <Foundation/Foundation.h>
#import "LeapObjectiveC.h"


@interface Sample : NSObject<LeapListener>

-(void)run:(NSView *)handView;

- (IBAction)goFullScreen:(id)sender;

- (IBAction)enableHandBounds:(id)sender;
- (IBAction)enableFingerLines:(id)sender;
- (IBAction)enableFingerTips:(id)sender;
- (IBAction)enableFingersZisY:(id)sender;
- (IBAction)enableDrawPalm:(id)sender;
- (IBAction)enableAutoHandSize:(id)sender;
- (IBAction)launchGRT:(id)sender;
- (IBAction)saveGRT:(id)sender;
- (IBAction)loadGRT:(id)sender;
- (IBAction)loadTestGRT:(id)sender;

@property (nonatomic) IBOutlet NSButton *runGRTButton;
@property (nonatomic) IBOutlet NSTextField *gestureName;

@end
