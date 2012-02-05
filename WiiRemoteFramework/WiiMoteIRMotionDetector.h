//
//  WiiMoteIRMotionDetector.h
//  WiiRemoteFramework
//
//  Created by Raul Gigea on 2/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WiiRemote.h"

typedef enum {
    eTopLeft = 0,
    eBottomLeft = 1,
    eBottomRight = 2,
    eTopRight = 3,
    eUndefined = 4
} IRMotionPointType;

@interface irDataSet : NSObject {
    IRData *irData;
}
@property (readonly) IRData *irData;
-(id)initWithData:(IRData*)_data;
@end

@interface WiiMoteIRMotionDetector : NSObject
{
    IRData	irData[4];
    BOOL running;
    
    // Advanced IR Motion Tracking
    
    // 0 = top-left, 1 = bottom-left, 2 = bottom-right, 3 = top-right
    // like this:
    //
    //     0----------3
    //      \        /
    //       \      /
    //        1----2
    //
    // @see IRMotionPointType
        
    int lastNumSeenPoints;
    
    IRData matchedIRData[4];    
    //IRData prevPositions[4];    
    
    // distance of each detected IR point to the bottom-left-point. Used for making the transition between tracked points seamless.
    IRData irPointDistance[4];    
    
    // The Point currently used for computing the Mouse Position
    IRMotionPointType trackedPoint;
    
    // Ideea: reference point = bottom-left
    // If the reference point is not visible, 
    // then we use as the position the last known difference to the reference point + the tracked point position
    // Mouse_Postion = Pos(Tracked_Point) + Diff(Tracked_Point, Reference_point)
    // While updating the Diff-Function every time the Reference Point is visible together with some other point. 
    // In doubt, the first tracked point is the reference point and is adjusted as it becomes obvious that the assumption was invalid
    
    int lastX, lastY;
    
    float trackedX, trackedY;
    
    // sensitivity Zoom around point (zoomX, zoomY)
    int zoomX, zoomY;
    BOOL enable_sensiZoom;

    //
    
    BOOL calibrate_range_mode;  // if enabled it records and updates the min/max of y & z
    BOOL center_calibrate_done; // set to false at begining of calibration and to true after all points were in range
    
    NSMutableArray *dataQueue;

    NSLock *lastPointLock;

    NSCondition *queueEmpty;

    WiiRemote *wiimote;
}

-(void) addIRData:(IRData *)data;
-(void) run;
-(IRData) getLastKnownPoint;

-(void) matchIRPoints;
-(void) updateTrackedPosition;


+(id) sharedInstance;

@property (assign) WiiRemote *wiimote;

@end
