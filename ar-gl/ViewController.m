//
//  ViewController.m
//  ar-gl
//
//  Created by Nikhilesh Sigatapu on 9/13/17.
//  Copyright © 2017 Nikhilesh Sigatapu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, strong) GLKView *rootView;
@property (nonatomic, strong) GLKViewController *glkViewController;
@property (nonatomic, strong) EAGLContext *eaglCtx;

@property (nonatomic, assign) Boolean initialized;

@property (nonatomic, assign) GLuint program;
@property (nonatomic, assign) int positionAttrib;
@property (nonatomic, assign) GLuint buffer;

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
}

static GLfloat verts[] = { -2.0f, 0.0f, 0.0f, -2.0f, 2.0f, 2.0f };

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
  if (!_initialized) {
    GLint status;
    
    // Compile vertex and fragment shader
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) STRINGIZE2(text)
    GLuint vert = glCreateShader(GL_VERTEX_SHADER);
    const char *vertSrc = STRINGIZE
    (
     precision highp float;
     attribute vec2 aPosition;
     void main() {
       gl_Position = vec4(1.0 - 2.0 * aPosition, 0, 1);
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
  glDrawArrays(GL_TRIANGLES, 0, 3);
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


@end
