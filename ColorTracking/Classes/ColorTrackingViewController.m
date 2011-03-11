//
//  ColorTrackingViewController.m
//  ColorTracking
//
//
//  The source code for this application is available under a BSD license.  See License.txt for details.
//
//  Created by Brad Larson on 10/7/2010.
//

#import "ColorTrackingViewController.h"

// Uniform index.
enum {
    UNIFORM_VIDEOFRAME,
	 UNIFORM_INPUTCOLOR,
	 UNIFORM_THRESHOLD,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

@implementation ColorTrackingViewController
@synthesize redSlider, greenSlider, blueSlider, sensitivitySlider;
@synthesize redLabel, greenLabel, blueLabel, sensitivityLabel;



#define DEBUG

#pragma mark - slider action methods

- (IBAction)sliderAction:(id)sender
{
	UISlider* slider = (UISlider *)sender;
	CGFloat val = [slider value];
   int sliderID = [slider tag];
   
   // this switch is not optimal but at least for now I want to understand what I am doing
   // we could do
   // thresholdColor[sliderID-1] = val;
   switch (sliderID) {
      case 1: // redSlider
         thresholdColor[0] = val;
         redLabel.text = [NSString stringWithFormat:@"R: %.2f", thresholdColor[0]];
         break;
      case 2: // greenSlider
         thresholdColor[1] = val;
         greenLabel.text = [NSString stringWithFormat:@"G: %.2f", thresholdColor[1]];
         break;
      case 3: // blueSlider
         thresholdColor[2] = val;
         blueLabel.text = [NSString stringWithFormat:@"B: %.2f", thresholdColor[2]];
         break;
      case 4: // sensitivitySlider
         thresholdSensitivity = val;
         sensitivityLabel.text = [NSString stringWithFormat:@"S: %.2f", thresholdSensitivity];
         break;
      default:
         break;
   }
}


#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithScreen:(UIScreen *)newScreenForDisplay;
{
    if ((self = [super initWithNibName:nil bundle:nil])) 
	{
		screenForDisplay = newScreenForDisplay;
		
		NSUserDefaults *currentDefaults = [NSUserDefaults standardUserDefaults];
		
		[currentDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:0.60], @"thresholdColorR", 
                                 [NSNumber numberWithFloat:0.05], @"thresholdColorG", 
                                 [NSNumber numberWithFloat:0.05], @"thresholdColorB", 
                                 [NSNumber numberWithFloat:0.75], @"thresholdSensitivity",
										   nil]];
      
      [[NSUserDefaults standardUserDefaults] setFloat:0.6f forKey:@"thresholdColorR"];
      [[NSUserDefaults standardUserDefaults] setFloat:0.05f forKey:@"thresholdColorG"];
      [[NSUserDefaults standardUserDefaults] setFloat:0.05f forKey:@"thresholdColorB"];
      [[NSUserDefaults standardUserDefaults] setFloat:0.7f forKey:@"thresholdSensitivity"];
      
      
		thresholdColor[0] = [currentDefaults floatForKey:@"thresholdColorR"];
		thresholdColor[1] = [currentDefaults floatForKey:@"thresholdColorG"];
		thresholdColor[2] = [currentDefaults floatForKey:@"thresholdColorB"];
		displayMode = PASSTHROUGH_VIDEO;
      // Custom initialization
		thresholdSensitivity = [currentDefaults floatForKey:@"thresholdSensitivity"];

      NSLog(@"Red: %g",thresholdColor[0]);
      NSLog(@"Green: %g",thresholdColor[1]);
      NSLog(@"Blue: %g",thresholdColor[2]);
      NSLog(@"Sensitivity: %g",thresholdSensitivity);
      
      
		rawPositionPixels = (GLubyte *) calloc(FBO_WIDTH * FBO_HEIGHT * 4, sizeof(GLubyte));	
      
   }
    return self;
}

- (void)loadView 
{
	CGRect applicationFrame = [screenForDisplay applicationFrame];	
	CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];	
	UIView *primaryView = [[UIView alloc] initWithFrame:mainScreenFrame];
	self.view = primaryView;
	[primaryView release];

	glView = [[ColorTrackingGLView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, applicationFrame.size.width, applicationFrame.size.height)];	
	[self.view addSubview:glView];
	[glView release];
	
	[self loadVertexShader:@"DirectDisplayShader" fragmentShader:@"DirectDisplayShader" forProgram:&directDisplayProgram];
	[self loadVertexShader:@"ThresholdShader" fragmentShader:@"ThresholdShader" forProgram:&thresholdProgram];
	[self loadVertexShader:@"PositionShader" fragmentShader:@"PositionShader" forProgram:&positionProgram];

  
   // Set up the toolbar at the bottom of the screen
	UISegmentedControl *displayModeControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:NSLocalizedString(@"Video", nil), NSLocalizedString(@"Threshold", nil), NSLocalizedString(@"Position", nil), NSLocalizedString(@"Track", nil), nil]];
	displayModeControl.segmentedControlStyle = UISegmentedControlStyleBar;
	displayModeControl.selectedSegmentIndex = 0;
	[displayModeControl addTarget:self action:@selector(handleSwitchOfDisplayMode:) forControlEvents:UIControlEventValueChanged];
	
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:displayModeControl];
	displayModeControl.frame = CGRectMake(0.0f, 5.0f, 300.0f, 30.0f);
	  
	NSArray *theToolbarItems = [NSArray arrayWithObjects:item, nil];
	
	UIToolbar *lowerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, self.view.frame.size.height - 44.0f, self.view.frame.size.width, 44.0f)];
	lowerToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	lowerToolbar.tintColor = [UIColor blackColor];
	
	[lowerToolbar setItems:theToolbarItems];
	[item release];
	
	[self.view addSubview:lowerToolbar];
	[lowerToolbar release];
	
	// Create the tracking dot
	trackingDot = [[CALayer alloc] init];
	trackingDot.bounds = CGRectMake(0.0f, 0.0f, 40.0f, 40.0f);
	trackingDot.cornerRadius = 20.0f;
	trackingDot.backgroundColor = [[UIColor blueColor] CGColor];
	
	NSMutableDictionary *newActions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"position",
									   nil];
	
	trackingDot.actions = newActions;
	[newActions release];

	[glView.layer addSublayer:trackingDot];
	trackingDot.position = CGPointMake(100.0f, 100.0f);
	trackingDot.opacity = 0.0f;
	
	camera = [[ColorTrackingCamera alloc] init];
	camera.delegate = self;
	[self cameraHasConnected];
   
   // Test Jim sliders for live modification of the tracked color
   [self setUIDefaults];
}

#pragma mark-
#pragma mark Test Jim sliders
// set the sliders values
- (void)setUIDefaults {
   // Test Jim sliders for live modification of the tracked color
   
   // red slider
   redSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
   redSlider.continuous    = YES;
   redSlider.minimumValue  = 0.0;
   redSlider.maximumValue  = 1.0;
   redSlider.value         = thresholdColor[0];
   redSlider.tag           = 1;
   [redSlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
   [self.view insertSubview:redSlider aboveSubview:glView];
   // red label
   redLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 0, 60, 20)];
   redLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
   redLabel.textColor = [UIColor whiteColor];
   [redLabel adjustsFontSizeToFitWidth];
   redLabel.text = [NSString stringWithFormat:@"R: %.2f", thresholdColor[0]];
   [self.view insertSubview:redLabel aboveSubview:glView];

   // green slider
   greenSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 50, 100, 30)];
   greenSlider.continuous   = YES;
   greenSlider.minimumValue = 0.0;
   greenSlider.maximumValue = 1.0;
   greenSlider.value        = thresholdColor[1];
   greenSlider.tag          = 2;
   [greenSlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
   [self.view insertSubview:greenSlider aboveSubview:glView];
   // green label
   greenLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 50, 60, 20)];
   greenLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
   greenLabel.textColor = [UIColor whiteColor];
   [greenLabel adjustsFontSizeToFitWidth];
   greenLabel.text = [NSString stringWithFormat:@"G: %.2f", thresholdColor[1]];
   [self.view insertSubview:greenLabel aboveSubview:glView];
   
   // blue slider
   blueSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 100, 100, 30)];
   blueSlider.continuous   = YES;
   blueSlider.minimumValue = 0.0;
   blueSlider.maximumValue = 1.0;
   blueSlider.value        = thresholdColor[2];
   blueSlider.tag          = 3;
   [blueSlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
   [self.view insertSubview:blueSlider aboveSubview:glView];
   
   // blue label
   blueLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 100, 60, 20)];
   blueLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
   blueLabel.textColor = [UIColor whiteColor];
   [blueLabel adjustsFontSizeToFitWidth];
   blueLabel.text = [NSString stringWithFormat:@"B: %.2f", thresholdColor[2]];
   [self.view insertSubview:blueLabel aboveSubview:glView];
   
   // sensitivity slider
   sensitivitySlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 150, 100, 30)];
   sensitivitySlider.continuous   = YES;
   sensitivitySlider.minimumValue = 0.0;
   sensitivitySlider.maximumValue = 1.0;
   sensitivitySlider.value        = thresholdSensitivity;
   sensitivitySlider.tag          = 4;
   [sensitivitySlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
   [self.view insertSubview:sensitivitySlider aboveSubview:glView];
   
   // sensitivity label
   sensitivityLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 150, 60, 20)];
   sensitivityLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
   sensitivityLabel.textColor = [UIColor whiteColor];
   [sensitivityLabel adjustsFontSizeToFitWidth];
   sensitivityLabel.text = [NSString stringWithFormat:@"S: %.2f", thresholdSensitivity];
   [self.view insertSubview:sensitivityLabel aboveSubview:glView];
}

- (void)didReceiveMemoryWarning 
{
//    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[trackingDot release];
	free(rawPositionPixels);
	[camera release];
   
   // Test Jim sliders
   [redSlider release];
   [greenSlider release];
   [blueSlider release];
   [sensitivitySlider release];

   [redLabel release];
   [greenLabel release];
   [blueLabel release];
   [sensitivityLabel release];
   
   [super dealloc];
}

#pragma mark -
#pragma mark OpenGL ES 2.0 rendering methods

- (void)drawFrame
{    
    // Replace the implementation of this method to do your own custom drawing.
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

	static const GLfloat textureVertices[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f,  1.0f,
        0.0f,  0.0f,
    };

/*	static const GLfloat passthroughTextureVertices[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f,  1.0f,
        1.0f,  1.0f,
    };
*/	
//    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
//    glClear(GL_COLOR_BUFFER_BIT);
    
	// Use shader program.
	switch (displayMode)
	{
		case PASSTHROUGH_VIDEO:
		{
			[glView setDisplayFramebuffer];
			glUseProgram(directDisplayProgram);
		}; break;
		case SIMPLE_THRESHOLDING:
		{
			[glView setDisplayFramebuffer];
			glUseProgram(thresholdProgram);
		}; break;
		case POSITION_THRESHOLDING:
		{
			[glView setDisplayFramebuffer];
			glUseProgram(positionProgram);			
		}; break;
		case OBJECT_TRACKING:
		{
			[glView setPositionThresholdFramebuffer];
			glUseProgram(positionProgram);			
		}; break;
	}		

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, videoFrameTexture);
	
	// Update uniform values
	glUniform1i(uniforms[UNIFORM_VIDEOFRAME], 0);	
	glUniform4f(uniforms[UNIFORM_INPUTCOLOR], thresholdColor[0], thresholdColor[1], thresholdColor[2], 1.0f);
	glUniform1f(uniforms[UNIFORM_THRESHOLD], thresholdSensitivity);
		
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureVertices);
	glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
	
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	if (displayMode == OBJECT_TRACKING)
	{
//		glGenerateMipmap(GL_TEXTURE_2D);
		
		
		// Grab the current position of the object from the offscreen framebuffer
		glReadPixels(0, 0, FBO_WIDTH, FBO_HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, rawPositionPixels);
		CGPoint currentTrackingLocation = [self centroidFromTexture:rawPositionPixels];
      
      if (!isnan(currentTrackingLocation.x)&& !isnan(currentTrackingLocation.y)) {
      
         trackingDot.position = CGPointMake(currentTrackingLocation.x * glView.bounds.size.width, currentTrackingLocation.y * glView.bounds.size.height);
         trackingDot.opacity = 1.0f;
      }
      else{
         trackingDot.position = CGPointMake(0, 0);
         trackingDot.opacity = 0.0f;
      }
		
		[glView setDisplayFramebuffer];
		glUseProgram(directDisplayProgram);

		// Grab the previously rendered texture and feed that into the next level of processing
//		glActiveTexture(GL_TEXTURE0);
//		glBindTexture(GL_TEXTURE_2D, glView.positionRenderTexture);
//		glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
//		glEnableVertexAttribArray(ATTRIB_VERTEX);
//		glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, passthroughTextureVertices);
//		glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);

	    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);		
	}
	else
	{
	}
   
   
   // Test Slider hiding
   if (displayMode == SIMPLE_THRESHOLDING) {
      redSlider.hidden = NO;
      redLabel.hidden = NO;
      greenSlider.hidden = NO;
      greenLabel.hidden = NO;
      blueSlider.hidden = NO;
      blueLabel.hidden = NO;
      sensitivitySlider.hidden = NO;
      sensitivityLabel.hidden = NO;
   }
   else {
      redSlider.hidden = YES;
      redLabel.hidden = YES;
      greenSlider.hidden = YES;
      greenLabel.hidden = YES;
      blueSlider.hidden = YES;
      blueLabel.hidden = YES;
      sensitivitySlider.hidden = YES;
      sensitivityLabel.hidden = YES;
   }
   
    
    [glView presentFramebuffer];
}

#pragma mark -
#pragma mark OpenGL ES 2.0 setup methods

- (BOOL)loadVertexShader:(NSString *)vertexShaderName fragmentShader:(NSString *)fragmentShaderName forProgram:(GLuint *)programPointer;
{
    GLuint vertexShader, fragShader;
	
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    *programPointer = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:vertexShaderName ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER file:vertShaderPathname])
    {
        NSLog(@"Failed to compile vertex shader");
        return FALSE;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShaderName ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname])
    {
        NSLog(@"Failed to compile fragment shader");
        return FALSE;
    }
    
    // Attach vertex shader to program.
    glAttachShader(*programPointer, vertexShader);
    
    // Attach fragment shader to program.
    glAttachShader(*programPointer, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(*programPointer, ATTRIB_VERTEX, "position");
    glBindAttribLocation(*programPointer, ATTRIB_TEXTUREPOSITON, "inputTextureCoordinate");
    
    // Link program.
    if (![self linkProgram:*programPointer])
    {
        NSLog(@"Failed to link program: %d", *programPointer);
        
        if (vertexShader)
        {
            glDeleteShader(vertexShader);
            vertexShader = 0;
        }
        if (fragShader)
        {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (*programPointer)
        {
            glDeleteProgram(*programPointer);
            *programPointer = 0;
        }
        
        return FALSE;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_VIDEOFRAME] = glGetUniformLocation(*programPointer, "videoFrame");
    uniforms[UNIFORM_INPUTCOLOR] = glGetUniformLocation(*programPointer, "inputColor");
    uniforms[UNIFORM_THRESHOLD] = glGetUniformLocation(*programPointer, "threshold");
    
    // Release vertex and fragment shaders.
    if (vertexShader)
	{
        glDeleteShader(vertexShader);
	}
    if (fragShader)
	{
        glDeleteShader(fragShader);		
	}
    
    return TRUE;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source)
    {
        NSLog(@"Failed to load vertex shader");
        return FALSE;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        glDeleteShader(*shader);
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

#pragma mark -
#pragma mark Display mode switching

- (void)handleSwitchOfDisplayMode:(id)sender;
{
	displayMode = [sender selectedSegmentIndex];
	
	if (displayMode == OBJECT_TRACKING)
	{
		trackingDot.opacity = 1.0f;
	}
	else
	{
		trackingDot.opacity = 0.0f;
	}
}

#pragma mark -
#pragma mark Image processing

- (CGPoint)centroidFromTexture:(GLubyte *)pixels;
{
	CGFloat currentXTotal = 0.0f, currentYTotal = 0.0f, currentPixelTotal = 0.0f;
	
	for (NSUInteger currentPixel = 0; currentPixel < (FBO_WIDTH * FBO_HEIGHT); currentPixel++)
	{
		currentYTotal += (CGFloat)pixels[currentPixel * 4] / 255.0f;
		currentXTotal += (CGFloat)pixels[(currentPixel * 4) + 1] / 255.0f;
		currentPixelTotal += (CGFloat)pixels[(currentPixel * 4) + 3] / 255.0f;
	}
	
	return CGPointMake(1.0f - (currentXTotal / currentPixelTotal), currentYTotal / currentPixelTotal);
}

#pragma mark -
#pragma mark ColorTrackingCameraDelegate methods

- (void)cameraHasConnected;
{
//	NSLog(@"Connected to camera");
/*	camera.videoPreviewLayer.frame = self.view.bounds;
	[self.view.layer addSublayer:camera.videoPreviewLayer];*/
}

- (void)processNewCameraFrame:(CVImageBufferRef)cameraFrame;
{
	CVPixelBufferLockBaseAddress(cameraFrame, 0);
	int bufferHeight = CVPixelBufferGetHeight(cameraFrame);
	int bufferWidth = CVPixelBufferGetWidth(cameraFrame);
	
	if (shouldReplaceThresholdColor)
	{
		// Extract a color at the touch point from the raw camera data
		int scaledVideoPointX = round((self.view.bounds.size.width - currentTouchPoint.x) * (CGFloat)bufferHeight / self.view.bounds.size.width);
		int scaledVideoPointY = round(currentTouchPoint.y * (CGFloat)bufferWidth / self.view.bounds.size.height);
		
		unsigned char *rowBase = (unsigned char *)CVPixelBufferGetBaseAddress(cameraFrame);
		int bytesPerRow = CVPixelBufferGetBytesPerRow(cameraFrame);
		unsigned char *pixel = rowBase + (scaledVideoPointX * bytesPerRow) + (scaledVideoPointY * 4);
		
		thresholdColor[0] = (float)pixel[2] / 255.0;
		thresholdColor[1] = (float)pixel[1] / 255.0;
		thresholdColor[2] = (float)pixel[0] / 255.0;
		
		[[NSUserDefaults standardUserDefaults] setFloat:thresholdColor[0] forKey:@"thresholdColorR"];
		[[NSUserDefaults standardUserDefaults] setFloat:thresholdColor[1] forKey:@"thresholdColorG"];
		[[NSUserDefaults standardUserDefaults] setFloat:thresholdColor[2] forKey:@"thresholdColorB"];

		shouldReplaceThresholdColor = NO;
	}

	// Create a new texture from the camera frame data, display that using the shaders
	glGenTextures(1, &videoFrameTexture);
	glBindTexture(GL_TEXTURE_2D, videoFrameTexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	// This is necessary for non-power-of-two textures
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	// Using BGRA extension to pull in video frame data directly
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));

	[self drawFrame];
	
	glDeleteTextures(1, &videoFrameTexture);

	CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
}


#pragma mark -
#pragma mark Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	currentTouchPoint = [[touches anyObject] locationInView:self.view];
	//shouldReplaceThresholdColor = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	CGPoint movedPoint = [[touches anyObject] locationInView:self.view]; 
	CGFloat distanceMoved = sqrt( (movedPoint.x - currentTouchPoint.x) * (movedPoint.x - currentTouchPoint.x) + (movedPoint.y - currentTouchPoint.y) * (movedPoint.y - currentTouchPoint.y) );

	thresholdSensitivity = distanceMoved / 160.0f;
	[[NSUserDefaults standardUserDefaults] setFloat:thresholdSensitivity forKey:@"thresholdSensitivity"];
   sensitivitySlider.value = thresholdSensitivity;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
}
        
                    
                    

#pragma mark -
#pragma mark Accessors

@synthesize glView;

@end
