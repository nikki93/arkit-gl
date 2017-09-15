//
//  ViewController.m
//  ar-gl
//
//  Created by Nikhilesh Sigatapu on 9/13/17.
//  Copyright © 2017 Nikhilesh Sigatapu. All rights reserved.
//

#import "ViewController.h"


#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) STRINGIZE2(text)


@interface ViewController ()

@property (nonatomic, assign) Boolean initialized;

// GL context
@property (nonatomic, strong) GLKView *rootView;
@property (nonatomic, strong) GLKViewController *glkViewController;
@property (nonatomic, strong) EAGLContext *eaglCtx;

// Camera texture
@property (nonatomic, assign) GLuint camProgram;
@property (nonatomic, assign) int camPositionAttrib;
@property (nonatomic, assign) GLuint camBuffer;
@property (nonatomic, assign) CVOpenGLESTextureRef camYTex;
@property (nonatomic, assign) CVOpenGLESTextureRef camCbCrTex;
@property (nonatomic, assign) CVOpenGLESTextureCacheRef camCache;

// Virtual scene
@property (nonatomic, assign) GLuint program;
@property (nonatomic, assign) int positionAttrib;
@property (nonatomic, assign) GLuint buffer;

// AR context
@property (nonatomic, strong) ARSession *arSession;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _initialized = NO;
  
  _eaglCtx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  _rootView = [[GLKView alloc] initWithFrame:self.view.frame context:_eaglCtx];
  _rootView.delegate = self;
  [self.view addSubview:_rootView];
  
  _glkViewController = [[GLKViewController alloc] init];
  _glkViewController.view = _rootView;
  _glkViewController.preferredFramesPerSecond = 60;
  
  _arSession = [[ARSession alloc] init];
  ARWorldTrackingConfiguration *arConfig = [[ARWorldTrackingConfiguration alloc] init];
  [_arSession runWithConfiguration:arConfig];
}

static GLfloat verts[] = { -2.0f, 0.0f, 0.0f, -2.0f, 2.0f, 2.0f };

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
  if (!_initialized) {
    GLint status;
    
    
    // Initialize camera texture cache
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _eaglCtx, NULL, &_camCache);
    if (err) {
      NSLog(@"Error from CVOpenGLESTextureCacheCreate(...): %d", err);
    }
    _camYTex = NULL;
    _camCbCrTex = NULL;
    
    // Compiler camera texture vertex and fragment shader
    GLuint camVert = glCreateShader(GL_VERTEX_SHADER);
    const char *camVertSrc = STRINGIZE
    (
      attribute vec2 position;
      varying vec2 vUv;
//      uniform mat4 rotationMatrix;
//      uniform float zoomRatio;
//      uniform bool needsCorrection;
     
//      const vec2 scale = vec2(0.5,0.5);
      void main() {
        vUv = position;
        gl_Position = vec4(1.0 - 2.0 * position, 0, 1);
        
        // if we need to correct perspective distortion,
//        if (needsCorrection) {
//          // fix scaling?
//          // https://stackoverflow.com/questions/24651369/blend-textures-of-different-size-coordinates-in-glsl/24654919#24654919
//          vec2 fromCenter = vUv - scale;
//          vec2 scaleFromCenter = fromCenter * vec2(zoomRatio);
//
//          vUv -= scaleFromCenter;
//        }
//        gl_Position = rotationMatrix* vec4(position,0.0,1.0);
//        gl_Position = vec4(position,0.0,1.0);
      }
    );
    glShaderSource(camVert, 1, &camVertSrc, NULL);
    glCompileShader(camVert);
    glGetShaderiv(camVert, GL_COMPILE_STATUS, &status);
    GLuint camFrag = glCreateShader(GL_FRAGMENT_SHADER);
    const char *camFragSrc = STRINGIZE
    (
     precision highp float;
     
     // this is the yyuv texture from ARKit
     uniform sampler2D yMap;
     uniform sampler2D uvMap;
     varying vec2 vUv;
     
     
     void main() {
       // flip uvs so image isn't inverted.
       vec2 textureCoordinate = vec2(vUv.t, vUv.s);
       
       // Using BT.709 which is the standard for HDTV
       mat3 colorConversionMatrix = mat3(
                                         1.164,  1.164, 1.164,
                                         0.0, -0.213, 2.112,
                                         1.793, -0.533,   0.0
                                         );
       
       mediump vec3 yuv;
       lowp vec3 rgb;
       
       yuv.x = texture2D(yMap, textureCoordinate).r - (16.0/255.0);
       yuv.yz = texture2D(uvMap, textureCoordinate).ra - vec2(0.5, 0.5);
       
       rgb = colorConversionMatrix * yuv;
       
       gl_FragColor = vec4(rgb,1.);
     }
    );
    glShaderSource(camFrag, 1, &camFragSrc, NULL);
    glCompileShader(camFrag);
    glGetShaderiv(camFrag, GL_COMPILE_STATUS, &status);
    
    // Link, use camera texture program, save and enable attributes
    _camProgram = glCreateProgram();
    glAttachShader(_camProgram, camVert);
    glAttachShader(_camProgram, camFrag);
    glLinkProgram(_camProgram);
    glUseProgram(_camProgram);
    _camPositionAttrib = glGetAttribLocation(_camProgram, "position");
    glEnableVertexAttribArray(_camPositionAttrib);
    
    // Create camera texture buffer
    glGenBuffers(1, &_camBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _camBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    
    // Bind camera texture 'position' attribute
    glVertexAttribPointer(_camPositionAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    
    // Compile vertex and fragment shader
    GLuint vert = glCreateShader(GL_VERTEX_SHADER);
    const char *vertSrc = STRINGIZE
    (
     precision highp float;
     attribute vec2 aPosition;
     uniform mat4 uProjection;
     uniform mat4 uView;
     void main() {
       gl_Position = uProjection * uView * vec4(aPosition, -5, 1);
     }
    );
    glShaderSource(vert, 1, &vertSrc, NULL);
    glCompileShader(vert);
    glGetShaderiv(vert, GL_COMPILE_STATUS, &status);
    GLuint frag = glCreateShader(GL_FRAGMENT_SHADER);
    const char *fragSrc = STRINGIZE
    (
     precision highp float;
     void main() {
       gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
     }
    );
    glShaderSource(frag, 1, &fragSrc, NULL);
    glCompileShader(frag);
    glGetShaderiv(frag, GL_COMPILE_STATUS, &status);
    
    // Link, use program, save and enable attributes
    _program = glCreateProgram();
    glAttachShader(_program, vert);
    glAttachShader(_program, frag);
    glLinkProgram(_program);
    glUseProgram(_program);
    _positionAttrib = glGetAttribLocation(_program, "aPosition");
    glEnableVertexAttribArray(_positionAttrib);
    
    // Create buffer
    glGenBuffers(1, &_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, _buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    
    // Bind 'position' attribute
    glVertexAttribPointer(_positionAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    _initialized = YES;
  }
  
  glClearColor(1.0, 0.0, 0.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  
  
  // Draw camera texture!
  
  glUseProgram(_camProgram);
  glEnableVertexAttribArray(_camPositionAttrib);
  glBindBuffer(GL_ARRAY_BUFFER, _camBuffer);
  glVertexAttribPointer(_camPositionAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);
  
  CVPixelBufferRef camPixelBuffer = _arSession.currentFrame.capturedImage;
  if (CVPixelBufferGetPlaneCount(camPixelBuffer) >= 2) {
    CVPixelBufferLockBaseAddress(camPixelBuffer, 0);
    
    CVBufferRelease(_camYTex);
    CVBufferRelease(_camCbCrTex);
    
    int width = (int) CVPixelBufferGetWidth(camPixelBuffer);
    int height = (int) CVPixelBufferGetHeight(camPixelBuffer);
    
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _camCache, camPixelBuffer, NULL,
                                                 GL_TEXTURE_2D, GL_LUMINANCE, width, height,
                                                 GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &_camYTex);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _camCache, camPixelBuffer, NULL,
                                                 GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, width / 2, height / 2,
                                                 GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_camCbCrTex);
    
    glBindTexture(CVOpenGLESTextureGetTarget(_camYTex), CVOpenGLESTextureGetName(_camYTex));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glBindTexture(CVOpenGLESTextureGetTarget(_camYTex), 0);
    glBindTexture(CVOpenGLESTextureGetTarget(_camCbCrTex), CVOpenGLESTextureGetName(_camCbCrTex));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glBindTexture(CVOpenGLESTextureGetTarget(_camCbCrTex), 0);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(CVOpenGLESTextureGetTarget(_camYTex), CVOpenGLESTextureGetName(_camYTex));
    glUniform1i(glGetUniformLocation(_camProgram, "yMap"), 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(CVOpenGLESTextureGetTarget(_camCbCrTex), CVOpenGLESTextureGetName(_camCbCrTex));
    glUniform1i(glGetUniformLocation(_camProgram, "uvMap"), 1);
    
    CVPixelBufferUnlockBaseAddress(camPixelBuffer, 0);
  }
  
  glDrawArrays(GL_TRIANGLES, 0, 3);
  
  CVOpenGLESTextureCacheFlush(_camCache, 0);
  
  
  // Draw triangle!
  
  glUseProgram(_program);
  glEnableVertexAttribArray(_positionAttrib);
  glBindBuffer(GL_ARRAY_BUFFER, _buffer);
  glVertexAttribPointer(_positionAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);
  
  GLint vp[4];
  glGetIntegerv(GL_VIEWPORT, vp);
  matrix_float4x4 viewMat = [_arSession.currentFrame.camera viewMatrixForOrientation:UIInterfaceOrientationPortrait];
  matrix_float4x4 projMat = [_arSession.currentFrame.camera projectionMatrixForOrientation:UIInterfaceOrientationPortrait viewportSize:CGSizeMake(vp[2], vp[3]) zNear:0.01 zFar:1000.0];
  glUniformMatrix4fv(glGetUniformLocation(_program, "uView"), 1, GL_FALSE, &viewMat.columns[0]);
  glUniformMatrix4fv(glGetUniformLocation(_program, "uProjection"), 1, GL_FALSE, &projMat.columns[0]);
  
  glDrawArrays(GL_TRIANGLES, 0, 3);
  
  
  matrix_float4x4 modMat = matrix_invert(viewMat);
  const float *pModMat = (const float *)(&modMat);
  NSLog(@"%f %f %f", pModMat[12], pModMat[13], pModMat[14]);
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


@end
