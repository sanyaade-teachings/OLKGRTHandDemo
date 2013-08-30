/******************************************************************************\
* Copyright (C) 2012-2013 Leap Motion, Inc. All rights reserved.               *
* Leap Motion proprietary and confidential. Not for distribution.              *
* Use subject to the terms of the Leap Motion SDK Agreement available at       *
* https://developer.leapmotion.com/sdk_agreement, or another agreement         *
* between Leap Motion and you, your company or other organization.             *
\******************************************************************************/

#import "Sample.h"
#import "OLKDemoHandsOverlayViewController.h"
#import "GRT.h"
using namespace GRT;

static const NSUInteger gSamplePoints = 41;

@implementation Sample
{
    LeapController *_controller;
    OLKDemoHandsOverlayViewController *_handsOverlayController;
    NSView *_handsView;
    BOOL _fullScreenMode;
    NSView *_fullOverlayView;
    NSWindow *_fullOverlayWindow;
    BOOL _trainingGRT;
    NSUInteger _prevFrameId;
    DTW *_dtw;
    LabelledTimeSeriesClassificationData *_trainingData;
    GestureRecognitionPipeline *_pipeline;
    MatrixDouble _timeSeries;
    NSUInteger _trainingClassLabel, _maxTrainingClassLabel;
    NSMutableDictionary *_gestureNameToClass;
}

@synthesize runGRTButton = _runGRTButton;
@synthesize gestureName = _gestureName;

- (void)dealloc
{
    free(_trainingData);
    _controller = nil;
    _handsOverlayController = nil;
}

-(void)run:(NSView *)handsView;
{
    _handsOverlayController = [[OLKDemoHandsOverlayViewController alloc] init];
    [_handsOverlayController setHandsContainerView:handsView];
    _controller = [[LeapController alloc] init];
    [_controller addListener:self];
    _handsView = handsView;
    NSLog(@"running");
    [_runGRTButton setTitle:@"Record Gesture"];
    _dtw = nil;
    _trainingData = nil;
    _pipeline = nil;
    _trainingClassLabel = 0;
    _maxTrainingClassLabel = _trainingClassLabel;
    _gestureNameToClass = [[NSMutableDictionary alloc] init];
}

#pragma mark - SampleListener Callbacks

- (void)onInit:(NSNotification *)notification
{
    _prevFrameId = 0;
    NSLog(@"Initialized");
}

- (void)onConnect:(NSNotification *)notification
{
    NSLog(@"Connected");
    LeapController *aController = (LeapController *)[notification object];
//    [aController enableGesture:LEAP_GESTURE_TYPE_CIRCLE enable:YES];
//    [aController enableGesture:LEAP_GESTURE_TYPE_KEY_TAP enable:YES];
//    [aController enableGesture:LEAP_GESTURE_TYPE_SCREEN_TAP enable:YES];
//    [aController enableGesture:LEAP_GESTURE_TYPE_SWIPE enable:YES];
}

- (void)onDisconnect:(NSNotification *)notification
{
    //Note: not dispatched when running in a debugger.
    NSLog(@"Disconnected");
}

- (void)onExit:(NSNotification *)notification
{
    NSLog(@"Exited");
}

- (IBAction)goFullScreen:(id)sender
{
    if (_fullScreenMode)
    {
        [[_handsView window] orderFront:self];
        _fullOverlayView = nil;
        [_fullOverlayWindow orderOut:self];
        _fullOverlayWindow = nil;
        _fullScreenMode = NO;
        [_handsOverlayController setHandsContainerView:_handsView];
        return;
    }
    _fullScreenMode = YES;
	NSRect mainDisplayRect;
	
    [[_handsView window] orderOut:self];
	// Create a screen-sized window on the display you want to take over
	// Note, mainDisplayRect has a non-zero origin if the key window is on a secondary display
	mainDisplayRect = [[NSScreen mainScreen] visibleFrame];
	_fullOverlayWindow = [[NSWindow alloc] initWithContentRect:mainDisplayRect styleMask:NSBorderlessWindowMask
                                                          backing:NSBackingStoreBuffered defer:YES];
	
	[_fullOverlayWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0]];
	[_fullOverlayWindow setOpaque:NO];
	
	// Set the window level to be above the menu bar
    [_fullOverlayWindow setLevel:NSMainMenuWindowLevel+1];
	
	// Perform any other window configuration you desire

    NSRect containerViewRect;
    containerViewRect.origin = NSMakePoint(0, 0);
    containerViewRect.size = [_fullOverlayWindow frame].size;    
    
    _fullOverlayView = [[NSView alloc] initWithFrame:containerViewRect];
        
	[_fullOverlayWindow setContentView:_fullOverlayView];

	// Show the window
	[_fullOverlayWindow makeKeyAndOrderFront:_fullOverlayWindow];
    [_fullOverlayWindow setAcceptsMouseMovedEvents:YES];
	[_fullOverlayWindow makeFirstResponder:_fullOverlayView];
    [_handsOverlayController setHandsContainerView:_fullOverlayView];
}

- (void)handsGestureDetect:(LeapFrame *)frame
{
    if (_pipeline == nil)
        return;
    VectorDouble sample(106);
    for (NSUInteger handCount=0; handCount < 2; handCount ++)
    {
        LeapHand *hand = nil;
        if (handCount < [[frame hands] count])
            hand = [[frame hands] objectAtIndex:handCount];
        if (hand)
        {
            sample.push_back([hand palmPosition].x);
            sample.push_back([hand palmPosition].y);
            sample.push_back([hand palmPosition].z);
            sample.push_back([hand palmNormal].x);
            sample.push_back([hand palmNormal].y);
            sample.push_back([hand palmNormal].z);
            sample.push_back([hand direction].x);
            sample.push_back([hand direction].y);
            sample.push_back([hand direction].z);
            sample.push_back([hand sphereCenter].x);
            sample.push_back([hand sphereCenter].y);
            sample.push_back([hand sphereCenter].z);
            sample.push_back([hand sphereRadius]);
        }
        else
        {
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
        }
        
        for (NSUInteger fingerCount = 0; fingerCount < 5; fingerCount ++)
        {
            LeapFinger *finger = nil;
            
            if (hand != nil && fingerCount < [[hand fingers] count])
                finger = [[hand fingers] objectAtIndex:fingerCount];
            if (finger)
            {
                sample.push_back([finger tipPosition].x);
                sample.push_back([finger tipPosition].y);
                sample.push_back([finger tipPosition].z);
                sample.push_back([finger direction].x);
                sample.push_back([finger direction].y);
                sample.push_back([finger direction].z);
                sample.push_back([finger length]);
                sample.push_back([finger width]);
            }
            else
            {
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
            }
        }
        
    }

    //If we are recording training data, then add the current sample to the training data set
    if( _trainingGRT ){
        _timeSeries.push_back(sample);
    }
    
    //If the pipeline has been trained, then run the prediction
    if( _pipeline->getTrained() && _trainingData->getNumSamples() > 5){
        _pipeline->predict(sample);
        if (_pipeline->getPredictedClassLabel() != 0)
        {
            NSLog(@"Detected Gesture %d", _pipeline->getPredictedClassLabel());
        }
    }
    
    return;
    
}

- (void)handsGestureDetectSimplified:(LeapFrame *)frame
{
    if (_pipeline == nil)
        return;
    VectorDouble sample;
    for (NSUInteger handCount=0; handCount < 1; handCount ++)
    {
        LeapHand *hand = nil;
        if (handCount < [[frame hands] count])
            hand = [[frame hands] objectAtIndex:handCount];
        if (hand)
        {
            sample.push_back([hand palmPosition].x);
            sample.push_back([hand palmPosition].y);
            sample.push_back([hand palmPosition].z);
            sample.push_back([hand palmNormal].x);
            sample.push_back([hand palmNormal].y);
            sample.push_back([hand palmNormal].z);
        }
        else
        {
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
            sample.push_back(0);
        }
        
        for (NSUInteger fingerCount = 0; fingerCount < 5; fingerCount ++)
        {
            LeapFinger *finger = nil;
            
            if (hand != nil && fingerCount < [[hand fingers] count])
                finger = [[hand fingers] objectAtIndex:fingerCount];
            if (finger)
            {
                sample.push_back([finger tipPosition].x);
                sample.push_back([finger tipPosition].y);
                sample.push_back([finger tipPosition].z);
                sample.push_back([finger direction].x);
                sample.push_back([finger direction].y);
                sample.push_back([finger direction].z);
                sample.push_back([finger length]);
            }
            else
            {
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
                sample.push_back(0);
            }
        }
        
    }
    
    //If we are recording training data, then add the current sample to the training data set
    if( _trainingGRT ){
        _timeSeries.push_back(sample);
    }
    
    //If the pipeline has been trained, then run the prediction
    if( _pipeline->getTrained() && _trainingData->getNumSamples() > 5){
        _pipeline->predict(sample);
        if (_pipeline->getPredictedClassLabel() != 0)
        {
            NSLog(@"Detected Gesture %d, with accuracy=%f", _pipeline->getPredictedClassLabel(), _pipeline->getTestAccuracy());
            double maximumLikelihood = _dtw->getMaximumLikelihood();
            VectorDouble classLikelihoods = _dtw->getClassLikelihoods();
            VectorDouble classDistances = _dtw->getClassDistances();
            
            cout << "\tMaximumLikelihood: " << maximumLikelihood << endl;        }
        
    }
    
    return;
    
}

- (void)onFrame:(NSNotification *)notification
{
    [_handsOverlayController onFrame:notification];
    
    LeapController *aController = (LeapController *)[notification object];
    
    // Get the most recent frame and report some basic information
    LeapFrame *frame = [aController frame:0];

    if ([frame identifier] == _prevFrameId)
        return;

//    [self handsGestureDetect:frame];
    [self handsGestureDetectSimplified:frame];
}

- (void)onFocusGained:(NSNotification *)notification
{
    NSLog(@"Focus Gained");
}

- (void)onFocusLost:(NSNotification *)notification
{
    NSLog(@"Focus Lost");
}

+ (NSString *)stringForState:(LeapGestureState)state
{
    switch (state) {
        case LEAP_GESTURE_STATE_INVALID:
            return @"STATE_INVALID";
        case LEAP_GESTURE_STATE_START:
            return @"STATE_START";
        case LEAP_GESTURE_STATE_UPDATE:
            return @"STATE_UPDATED";
        case LEAP_GESTURE_STATE_STOP:
            return @"STATE_STOP";
        default:
            return @"STATE_INVALID";
    }
}

- (IBAction)enableHandBounds:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableDrawHandsBoundingCircle:YES];
    else
        [_handsOverlayController setEnableDrawHandsBoundingCircle:NO];
}

- (IBAction)enableFingerLines:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableDrawFingers:YES];
    else
        [_handsOverlayController setEnableDrawFingers:NO];
}

- (IBAction)enableFingerTips:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableDrawFingerTips:YES];
    else
        [_handsOverlayController setEnableDrawFingerTips:NO];
}

- (IBAction)enableFingersZisY:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableScreenYAxisUsesZAxis:YES];
    else
        [_handsOverlayController setEnableScreenYAxisUsesZAxis:NO];
}

- (IBAction)enableDrawPalm:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableDrawPalms:YES];
    else
        [_handsOverlayController setEnableDrawPalms:NO];
}

- (IBAction)enableAutoHandSize:(id)sender
{
    if ([(NSButton*)sender state] == NSOnState)
        [_handsOverlayController setEnableAutoFitHands:YES];
    else
        [_handsOverlayController setEnableAutoFitHands:NO];
}

- (void)stopTrainingGRT
{
    _trainingData->addSample((unsigned int)_trainingClassLabel, _timeSeries);
    if( !_pipeline->train(*_trainingData) ){
        cout << "Failed to train classifier!\n";
        return ;
    }
    _trainingGRT = FALSE;
}

- (void)loadTrainingGRT
{
    if (!_trainingData)
        [self setupGRT];
    
    NSString *execPath = [[[NSBundle mainBundle] executablePath]  stringByDeletingLastPathComponent];
    const char *trainingFilename = [[execPath stringByAppendingPathComponent:@"DTWTrainingData.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if( !_trainingData->loadDatasetFromFile(trainingFilename) ){
        cout << "Failed to load training data!\n";
        return;
    }
}

- (void)loadModelGRT
{
    if (!_pipeline)
        [self setupGRT];
    
    NSString *execPath = [[[NSBundle mainBundle] executablePath]  stringByDeletingLastPathComponent];
    const char *modelFilename = [[execPath stringByAppendingPathComponent:@"DTWModelData.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if( !_pipeline->getClassifier()->loadModelFromFile(modelFilename) ){
        cout << "Failed to load gesture model!\n";
        return;
    }
}

- (void)saveTrainingGRT
{
    NSString *execPath = [[[NSBundle mainBundle] executablePath]  stringByDeletingLastPathComponent];
    const char *trainingFilename = [[execPath stringByAppendingPathComponent:@"DTWTrainingData.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if( !_trainingData->saveDatasetToFile(trainingFilename) )
        cout << "Failed to save the training data!\n";
}

- (void)saveModelGRT
{
    NSString *execPath = [[[NSBundle mainBundle] executablePath]  stringByDeletingLastPathComponent];
    const char *modelFilename = [[execPath  stringByAppendingPathComponent:@"DTWModel.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    //Save the DTW model to a file
    if( !_pipeline->getClassifier()->saveModelToFile(modelFilename) ){
        cout << "Failed to save the classifier model!\n";
        return;
    }
}

- (void)setupGRT
{
    _dtw = new DTW();
    _dtw->enableNullRejection(TRUE);
    //Set the null rejection coefficient to 3, this controls the thresholds for the automatic null rejection
    //You can increase this value if you find that your real-time gestures are not being recognized
    //If you are getting too many false positives then you should decrease this value
    _dtw->setNullRejectionCoeff( 0.3 );
    
    //Turn on the automatic data triming, this will remove any sections of none movement from the start and end of the training samples
    _dtw->enableTrimTrainingData(true, 0.1, 90);
    
    //Offset the timeseries data by the first sample, this makes your gestures (more) invariant to the location the gesture is performed
    _dtw->setOffsetTimeseriesUsingFirstSample(true);
    _trainingData = new LabelledTimeSeriesClassificationData();
    _trainingData->setNumDimensions( gSamplePoints );
    _pipeline = new GestureRecognitionPipeline();
    _pipeline->setClassifier(*_dtw);
}

- (void)startTrainingGRT
{
    _trainingGRT = TRUE;

    NSString *gestureName = [_gestureName stringValue];
    NSNumber *classNum = [_gestureNameToClass objectForKey:gestureName];
    
    if (classNum == nil)
    {
        _timeSeries.clear();
        _timeSeries.resize(0, gSamplePoints);
        _maxTrainingClassLabel ++;
        _trainingClassLabel = _maxTrainingClassLabel;
        [_gestureNameToClass setObject:[NSNumber numberWithUnsignedInteger:_trainingClassLabel] forKey:gestureName];
    }
    else if ([classNum unsignedIntegerValue] != _trainingClassLabel)
    {
        _timeSeries.clear();
        _timeSeries.resize(0, gSamplePoints);
        _trainingClassLabel = [classNum unsignedIntegerValue];
    }
    
    if (!_pipeline)
    {
        [self setupGRT];
    }

    return;
}

- (IBAction)loadTestGRT:(id)sender
{
    DTW dtw;
    //Load some training data to train the classifier - the DTW uses LabelledTimeSeriesClassificationData
    LabelledTimeSeriesClassificationData trainingData;
    
    NSString *execPath = [[[NSBundle mainBundle] executablePath]  stringByDeletingLastPathComponent];
    const char *trainingFilename = [[execPath stringByAppendingPathComponent:@"DTWTestTrainingData.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if( !trainingData.loadDatasetFromFile(trainingFilename) ){
        cout << "Failed to load training data!\n";
        return;
    }
    
    LabelledTimeSeriesClassificationData testData = trainingData.partition( 80 );
    dtw.enableNullRejection(TRUE);
    
    //Train the classifier
    if( !dtw.train( trainingData ) ){
        cout << "Failed to train classifier!\n";
        return ;
    }
    
    const char *modelFilename = [[execPath  stringByAppendingPathComponent:@"DTWTestModel.txt"] cStringUsingEncoding:NSASCIIStringEncoding];
    //Save the DTW model to a file
    if( !dtw.saveModelToFile(modelFilename) ){
        cout << "Failed to save the classifier model!\n";
        return;
    }
    
    //Load the DTW model from a file
    if( !dtw.loadModelFromFile(modelFilename) ){
        cout << "Failed to load the classifier model!\n";
        return;
    }
    
    //Use the test dataset to test the DTW model
    double accuracy = 0;
    for(UINT i=0; i<testData.getNumSamples(); i++){
        //Get the i'th test sample - this is a timeseries
        UINT classLabel = testData[i].getClassLabel();
        MatrixDouble timeseries = testData[i].getData();
        
        //Perform a prediction using the classifier
        if( !dtw.predict( timeseries ) ){
            cout << "Failed to perform prediction for test sampel: " << i <<"\n";
            return;
        }
        
        //Get the predicted class label
        UINT predictedClassLabel = dtw.getPredictedClassLabel();
        double maximumLikelihood = dtw.getMaximumLikelihood();
        VectorDouble classLikelihoods = dtw.getClassLikelihoods();
        VectorDouble classDistances = dtw.getClassDistances();
        
        //Update the accuracy
        if( classLabel == predictedClassLabel ) accuracy++;
        
        cout << "TestSample: " << i <<  "\tClassLabel: " << classLabel << "\tPredictedClassLabel: " << predictedClassLabel << "\tMaximumLikelihood: " << maximumLikelihood << endl;
    }
    
    cout << "Test Accuracy: " << accuracy/double(testData.getNumSamples())*100.0 << "%" << endl;

}

- (IBAction)loadGRT:(id)sender
{
    [self loadTrainingGRT];
    [self loadModelGRT];
}

- (IBAction)saveGRT:(id)sender
{
    [self saveTrainingGRT];
    [self saveModelGRT];
}

- (IBAction)launchGRT:(id)sender
{
    
    if (_trainingGRT)
    {
        [_runGRTButton setTitle:@"Record Gesture"];
        [self stopTrainingGRT];
    }
    else
    {
        [_runGRTButton setTitle:@"Stop Recording"];
        [self startTrainingGRT];
    }
}

@end
