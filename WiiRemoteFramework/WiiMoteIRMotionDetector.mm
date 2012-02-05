//
//  WiiMoteIRMotionDetector.m
//  WiiRemoteFramework
//
//  Created by Raul Gigea on 2/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WiiMoteIRMotionDetector.h"

@implementation irDataSet
@synthesize irData;
-(id) initWithData:(IRData *)_data
{
    if ( (self = [super init]) )
    {
        irData = (IRData*)malloc(sizeof(IRData)*4);
        for (int i = 0; i < 4; i++)
            irData[i] = _data[i];
    }
    return self;
}
-(void) dealloc
{
    free(irData);
    [super dealloc];
}
@end

float sqsum(float x, float y)
{
    return x*x + y*y;
}

float sqDiff(IRData &p1, IRData &p2)
{
    return sqsum(p1.x - p2.x, p1.y-p2.y);
}

int minX_except(IRData *p, int except)
{
    int minv = 100000;
    int min = 0;
    if (min == except)
        min++;
    
    for (int i = 0; i < 4; i++)
        if ( i != except && minv > p[i].x )
        {
            minv = p[i].x;
            min = i;
        }
    
    return min;
}

int minY_except(IRData *p, int except)
{
    int minv = 100000;
    int min = 0;
    if (min == except)
        min++;
    
    for (int i = 0; i < 4; i++)
        if ( i != except && minv > p[i].y )
        {
            minv = p[i].y;
            min = i;
        }
    
    return min;
}

WiiMoteIRMotionDetector *singleton = nil;

@implementation WiiMoteIRMotionDetector
@synthesize wiimote;

+(id) sharedInstance
{
    if ( singleton == nil )
    {
        singleton = [[WiiMoteIRMotionDetector alloc] init];
    }
    
    return singleton;
}

-(id)init
{
    if ( ( self = [super init] ) )
    {
        lastPointLock = [[NSLock alloc] init];
        queueEmpty = [[NSCondition alloc] init];
        dataQueue = [[NSMutableArray alloc] init];
        running = NO;
    }
    
    return self;
}

-(void) run
{
    if ( running )  // prevent more than one instance of itself to be running
        return;
    
    running = YES;
    
    while ( YES )
    {
        // wait for dataQueue do have an object
        // process object
        // remote object from dataQueue
        // if dataQueue > limit, ERROR & quit

        [queueEmpty lock];
        
        while ( dataQueue.count == 0 )
        {
            [queueEmpty wait];
        }
        
        int count = dataQueue.count;
        
        irDataSet *data = [[dataQueue objectAtIndex:0] retain];
        [dataQueue removeObjectAtIndex:0];
                
    
        if ( count > 100 )
        {
            NSLog(@"Hmm ... the data keeps piling up man. Seems we're too slow at processing the incomming irData so we should probably skip some ...");
            [dataQueue removeAllObjects];
        }

        [queueEmpty unlock];
        
        // now do recognition
        
        for (int i = 0; i < 4 ; i++)
            irData[i] = data.irData[i];
        
        [data release];
        
        [self updateTrackedPosition];
        
        
    }
}

-(void) addIRData:(IRData*) _data
{
    irDataSet *data = [[[irDataSet alloc] initWithData:_data] autorelease];

    [queueEmpty lock];

    [dataQueue addObject:data];

    [queueEmpty signal];
    [queueEmpty unlock];
    
}

-(IRData) getLastKnownPoint
{
    IRData result;
    [lastPointLock lock];
    
    result.x = lastX;
    result.y = lastY;
    
    [lastPointLock unlock];
    
    return result;
}

-(void) vibrate_baby
{
    [wiimote setForceFeedbackEnabled:YES];
    
    [NSThread sleepForTimeInterval:0.1];
    
    [wiimote setForceFeedbackEnabled:NO];
}

-(void) update_leds
{
        [wiimote setLEDEnabled1:matchedIRData[0].s < 0x0F 
                    enabled2:matchedIRData[1].s < 0x0F 
                    enabled3:matchedIRData[2].s < 0x0F 
                    enabled4:matchedIRData[3].s < 0x0F];
}

-(void) matchIRPoints
{
    //NSLog(@"matching IR Points");
    
    IRMotionPointType ref = eTopLeft;
    
    int numSeenPoints = 0;
    
    IRMotionPointType matches[4] = {eUndefined, eUndefined, eUndefined, eUndefined} ;
    
    /*
     
     Problemstellung:
     
     Sei M1 = { a1, a2, a3, a4 }, M2 = { b1, b2, b3, b4}, a_i, b_i \in R^2 zwei mengen von 4 punkte;
     
     M1 = irData (current points), M2 = matchedIRData ( prev points )
     
     finde eine Zuordnung f : M1 -> M2, so dass:
     
     f - bijektiv UND, ( d.h. f(a_i) != f(a_j) fuer jedes i,j in 1...4, und \exists f(a_i) fuer jedes i in 1..4) 
     
     Summe d(a_i, f(a_i)) = Min, fuer i \n 1...4      
     
     Faktoren zu berücksichtigen in der Zuordnung:
     
     - Abstand von Punkt a_i aus M1 zu Punkt b_i aus M2
     - geometrische Beziehung von punkte b_i zu b_j ( Lop-Left/Bottom-Left,Top-Right/Bottom-Right )
     
     
     optional:
     - Geschwindigkeit von punkte b_i + b_i zu a_j, wo f(a_j)=b_i
     
     */
        
    float minergy = 1000000000.0;
    
    //NSLog(@"computing minimum energy");
    
    
    for (int p1 = 0; p1 < 4; p1++)
        for (int p2 = 0; p2 < 4; p2++)
            if ( p1 != p2 )
                for (int p3 = 0; p3 < 4; p3++)
                    if ( p3 != p1 && p3 != p2 )
                        for (int p4 = 0; p4 < 4; p4++)
                            if ( p4 != p1 && p4 != p2 && p4 != p3 )
                            {
                                // calculate engergy
                                // squared error
                                
                                float energy = 
                                ((irData[0].s < 0x0F)?1:0) * sqDiff(irData[0], matchedIRData[p1]) +
                                ((irData[1].s < 0x0F)?1:0) * sqDiff(irData[1], matchedIRData[p2]) +
                                ((irData[2].s < 0x0F)?1:0) * sqDiff(irData[2], matchedIRData[p3]) +
                                ((irData[3].s < 0x0F)?1:0) * sqDiff(irData[3], matchedIRData[p4]);
                                
                                
                                
                                if ( energy < minergy )
                                {
                                    minergy = energy;
                                    matches[0] = (IRMotionPointType)p1;
                                    matches[1] = (IRMotionPointType)p2;
                                    matches[2] = (IRMotionPointType)p3;
                                    matches[3] = (IRMotionPointType)p4;
                                }
                                
                            }
    
    numSeenPoints = 4;
    for (int i = 0; i < 4; i++)
    {
        if ( irData[i].s >= 0x0F )
        {
            numSeenPoints--;
            matches[i] = eUndefined;
        }
        
        matchedIRData[i].s = 0x0F;
    }
    
    //NSLog(@"geometric verification");
    
    // geometric verification step
    
    // if all 4 points visible -> obvious
    if ( numSeenPoints == 4 )
    {
        int leftPoints[2], rightPoints[2] = {-1,-1};
        
        leftPoints[0] = minX_except( irData, -1 );
        leftPoints[1] = minX_except( irData, leftPoints[0] );
        
        for (int i = 0; i < 4; i++)
        {
            if ( i != leftPoints[0] && i != leftPoints[1] )
            {
                if ( rightPoints[0] == -1 )
                    rightPoints[0] = i;
                else if ( rightPoints[1] == -1 )
                    rightPoints[1] = i;
            }
        }
        
        int revMatches[4];
        revMatches[eTopLeft] = ( irData[ leftPoints[0] ].y < irData[ leftPoints[1] ].y ) ? leftPoints[0] : leftPoints[1];
        revMatches[eBottomLeft] = ( irData[ leftPoints[0] ].y < irData[ leftPoints[1] ].y ) ? leftPoints[1] : leftPoints[0];
        
        revMatches[eTopRight] = ( irData[ rightPoints[0] ].y < irData[ rightPoints[1] ].y ) ? rightPoints[0] : rightPoints[1];
        revMatches[eBottomRight] = ( irData[ rightPoints[0] ].y < irData[ rightPoints[1] ].y ) ? rightPoints[1] : rightPoints[0];
        
        // nearest matches:
        // match[i] = j, i = irData, j = matchedIRData
        // revMatches[j] = i, j = matchedIRData, i = irData
        
        // swap irPointDistances ( swap geometric matches for nearest ones )
        
        for (int i = 0; i < 4; i++)
        {
            // vorher war match[0] = (j) eTopLeft 
            // jetzt ist (j) eTopLeft aber revMatches[(j) eTopLeft] 
            // vorher war aber revMatches[(j)eTopLeft] aber bei 
            // match[revMatches[(j)eTopLeft]] = k(eBottomLeft)
            
            // also muss man match[revMatches[match[0]]] mit match[0] tauschen
            
            int p1 = matches[i];
            if ( p1 != eUndefined )
            {
                int p2 = matches[revMatches[p1]];
                if ( p2 != eUndefined )
                {
                    // switch irPointDistance of p1 with p2
                    IRData temp = irPointDistance[p1];
                    irPointDistance[p1] = irPointDistance[p2];
                    irPointDistance[p2] = temp;
                }
            }
        }
        
        for (int i = 0; i < 4; i++)
            matches[revMatches[i]] = (IRMotionPointType)i;
    }
    
    
    // if only 2 points visible -> if one of them is known -> infer the other one
    // else, assume the reference-point is visible and infer the other one
    if ( numSeenPoints == 2 )
    {
        
    }
    
    // now assign all matchedIRData's
    //NSLog(@"assign new matchedIRData");
    
    for (int i = 0; i < 4;i++)
    {
        if ( matches[i] != eUndefined )
            matchedIRData[matches[i]] = irData[i];
    }
    
    [self update_leds];
    
    if ( lastNumSeenPoints != numSeenPoints && numSeenPoints == 4 )
    {
        [self performSelectorInBackground:@selector(vibrate_baby) withObject:nil];
    }
    
    lastNumSeenPoints = numSeenPoints;
    
}



-(void) updateTrackedPosition
{
    IRMotionPointType ref = eTopLeft;
    
    IRMotionPointType lastTrackedPoint = trackedPoint;
    //    IRData lastTrackedIRData = matchedIRData[lastTrackedPoint];
    [self matchIRPoints];
    
    trackedPoint = eUndefined;
    
    // waehle eins der sichtbaren punkte als tracking point zum berechnen der getrackten position
    for (int i = 0; i < 4; i++)
    {
        if ( matchedIRData[i].s < 0x0F )
        {
            trackedPoint = (IRMotionPointType)i;
            break;
        }
    }
    
    // bevorzuge den refenence point als tracking punkt
    if ( matchedIRData[ref].s < 0x0F )
    {
        trackedPoint = ref;
    }
    
    // Update all visible points Difference Vector to the tracked Point
    for (int i = 0; i < 4; i++)
    {
        // don't adjust the tracked Points Difference Vector unless we switched tracking Points !
        if ( ( i != lastTrackedPoint ) && ( matchedIRData[i].s < 0x0F ) )
        {
            irPointDistance[i].x = lastX - matchedIRData[i].x;    
            irPointDistance[i].y = lastY - matchedIRData[i].y;    
        }
    }
    
    if ( trackedPoint != eUndefined )
    {
        [lastPointLock lock];

        lastX = irPointDistance[trackedPoint].x + matchedIRData[trackedPoint].x;
        lastY = irPointDistance[trackedPoint].y + matchedIRData[trackedPoint].y;

        [lastPointLock unlock];

        
        // try to bring the referece point back to absolute zero by slowly interpolating
        // all other points don't do this -> reference point = absolute zero !
        if ( trackedPoint == ref && ( (fabs(irPointDistance[ref].x) > 0) || (fabs(irPointDistance[ref].y) > 0) ) )
        {
            NSLog(@"normalizing reference point distance: (%d,%d)", irPointDistance[ref].x, irPointDistance[ref].y);
            irPointDistance[ref].x *= 0.8;
            irPointDistance[ref].y *= 0.8;
        }
        
        trackedX = 1 - lastX / 1024.0;
        trackedY = 1 - lastY / 768.0;    
    }
    
    //NSLog(@"(%d,%d)", lastX, lastY);
    
}


@end
