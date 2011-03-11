//
//  ColorTrackingViewController.h
//  ColorTracking
//
//
//  The source code for this application is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 10/7/2010.
//

#import <UIKit/UIKit.h>
#import "ColorTrackingCamera.h"
#import "ColorTrackingGLView.h"

typedef enum { PASSTHROUGH_VIDEO, SIMPLE_THRESHOLDING, POSITION_THRESHOLDING, OBJECT_TRACKING} ColorTrackingDisplayMode;


@interface ColorTrackingViewController : UIViewController <ColorTrackingCameraDelegate>
{
	ColorTrackingCamera *camera;
	UIScreen *screenForDisplay;
	ColorTrackingGLView *glView;
	CALayer *trackingDot;
	
	ColorTrackingDisplayMode displayMode;
	
	BOOL shouldReplaceThresholdColor;
	CGPoint currentTouchPoint;
	GLfloat thresholdSensitivity;
	GLfloat thresholdColor[3];
	
	GLuint directDisplayProgram, thresholdProgram, positionProgram;
	GLuint videoFrameTexture;
	
	GLubyte *rawPositionPixels;
   
   // Test Jim sliders for live modification of the tracked color
   IBOutlet UISlider *redSlider;
   IBOutlet UISlider *greenSlider;
   IBOutlet UISlider *blueSlider;
   IBOutlet UISlider *sensitivitySlider;
   
   IBOutlet UILabel *redLabel;
   IBOutlet UILabel *greenLabel;
   IBOutlet UILabel *blueLabel;
   IBOutlet UILabel *sensitivityLabel;
}

@property(readonly) ColorTrackingGLView *glView;

@property (retain, nonatomic) UISlider *redSlider;
@property (retain, nonatomic) UISlider *greenSlider;
@property (retain, nonatomic) UISlider *blueSlider;
@property (retain, nonatomic) UISlider *sensitivitySlider;

@property (retain, nonatomic) UILabel *redLabel;
@property (retain, nonatomic) UILabel *greenLabel;
@property (retain, nonatomic) UILabel *blueLabel;
@property (retain, nonatomic) UILabel *sensitivityLabel;



// Initialization and teardown
- (id)initWithScreen:(UIScreen *)newScreenForDisplay;

// OpenGL ES 2.0 setup methods
- (BOOL)loadVertexShader:(NSString *)vertexShaderName fragmentShader:(NSString *)fragmentShaderName forProgram:(GLuint *)programPointer;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

// Display mode switching
- (void)handleSwitchOfDisplayMode:(id)sender;

// Image processing
- (CGPoint)centroidFromTexture:(GLubyte *)pixels;

// Test Jim sliders
- (IBAction)sliderAction:(id)sender;
//- (IBAction)greenSliderValueChanged:(id)sender;
//- (IBAction)blueSliderValueChanged:(id)sender;
//- (IBAction)sensitivitySliderValueChanged:(id)sender;

- (void)setUIDefaults; // setting defaults for the sliders

@end

