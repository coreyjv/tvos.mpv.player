//
//  ViewController.m
//  mpv-demo

@import GLKit;
@import OpenGLES;
@import UIKit;

#import "ViewController.h"

#import "client.h"
#import "opengl_cb.h"

#import <AVKit/AVKit.h>

#import <stdio.h>
#import <stdlib.h>


static inline void check_error(int status)
{
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
        exit(1);
    }
}

static void *get_proc_address(void *ctx, const char *name)
{
    CFStringRef symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    void *addr = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengles")), symbolName);
    CFRelease(symbolName);
    return addr;
}

static void glupdate(void *ctx);

@interface MpvClientOGLView : GLKView
    @property mpv_opengl_cb_context *mpvGL;
    @end

@implementation MpvClientOGLView {
    GLint defaultFBO;
}
    
    
- (id)initWithFrame:(CGRect)frame
    {
        self = [super initWithFrame:frame];
        
        
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!self.context) {
            NSLog(@"Failed to initialize OpenGLES 2.0 context");
            exit(1);
        }
        [EAGLContext setCurrentContext:self.context];
        
        // Configure renderbuffers created by the view
        self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
        self.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
        self.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
        
        defaultFBO = -1;
        self.opaque = true;
        
        [self fillBlack];
        
        return self;
    }
    
- (void)fillBlack
    {
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
- (void)drawRect
    {
        if (defaultFBO == -1)
        {
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &defaultFBO);
        }
        
        if (self.mpvGL)
        {
            mpv_opengl_cb_draw(self.mpvGL,
                               defaultFBO,
                               self.bounds.size.width * self.contentScaleFactor,
                               -self.bounds.size.height * self.contentScaleFactor);
        }
    }
    
- (void)drawRect:(CGRect)rect
    {
        [self drawRect];
    }
    
    
    @end



static void wakeup(void *);


static void glupdate(void *ctx)
{
    MpvClientOGLView *glView = (__bridge MpvClientOGLView *)ctx;
    
    // I'm still not sure what the best way to handle this is, but this
    // works.
    dispatch_async(dispatch_get_main_queue(), ^{
        [glView display];
    });
}


@interface ViewController ()
    
    @property (nonatomic) MpvClientOGLView *glView;
- (void) readEvents;
    
@end

static void wakeup(void *context)
{
    ViewController *a = (__bridge ViewController *) context;
    [a readEvents];
}



@implementation ViewController {
    mpv_handle *mpv;
    dispatch_queue_t queue;
}
    
- (void)loadView {
    [super loadView];
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    
    // set up the mpv player view
    _glView = [[MpvClientOGLView alloc] initWithFrame:screenBounds];
    
    
    mpv = mpv_create();
    if (!mpv) {
        printf("failed creating context\n");
        exit(1);
    }
    
    
    // request important errors -- extract this file with iTunes file sharing
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *fileName =[NSString stringWithFormat:@"mpv-%@.log",[NSDate date]];
    NSString *logFile = [documentsDirectory stringByAppendingPathComponent:fileName];
    NSLog(@"%@", logFile);
    
    check_error(mpv_set_option_string(mpv, "log-file", logFile.UTF8String));
    check_error(mpv_request_log_messages(mpv, "status"));
    check_error(mpv_initialize(mpv));
    check_error(mpv_set_option_string(mpv, "vo", "opengl-cb"));
    check_error(mpv_set_option_string(mpv, "hwdec", "yes"));
    check_error(mpv_set_option_string(mpv, "hwdec-codecs", "all"));
    
    mpv_opengl_cb_context *mpvGL = mpv_get_sub_api(mpv, MPV_SUB_API_OPENGL_CB);
    if (!mpvGL) {
        puts("libmpv does not have the opengl-cb sub-API.");
        exit(1);
    }
    
    [self.glView display];
    
    // pass the mpvGL context to our view
    self.glView.mpvGL = mpvGL;
    int r = mpv_opengl_cb_init_gl(mpvGL, NULL, get_proc_address, NULL);
    if (r < 0) {
        puts("gl init has failed.");
        exit(1);
    }
    mpv_opengl_cb_set_update_callback(mpvGL, glupdate, (__bridge void *)self.glView);
    
    
    // Deal with MPV in the background.
    queue = dispatch_queue_create("mpv", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        // Register to be woken up whenever mpv generates new events.
        mpv_set_wakeup_callback(mpv, wakeup, (__bridge void *)self);
        // Load the indicated file
        
        const char *cmd[] = {"loadfile", "http://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_640x360.m4v", NULL};
        //        NSURL *movieURL = [[NSBundle mainBundle] URLForResource:@"hevc-test-soccer" withExtension:@"mts"];
        //        const char *cmd[] = {"loadfile", [movieURL.absoluteString UTF8String], NULL};
        check_error(mpv_command(mpv, cmd));
        check_error(mpv_set_option_string(mpv, "loop", "inf"));
    });
    
    
    [self.view addSubview:_glView];
}
    
- (void)handleEvent:(mpv_event *)event
    {
        switch (event->event_id) {
            case MPV_EVENT_SHUTDOWN: {
                mpv_detach_destroy(mpv);
                mpv_opengl_cb_uninit_gl(self.glView.mpvGL);
                mpv = NULL;
                printf("event: shutdown\n");
                break;
            }
            
            case MPV_EVENT_LOG_MESSAGE: {
                struct mpv_event_log_message *msg = (struct mpv_event_log_message *)event->data;
                printf("[%s] %s: %s", msg->prefix, msg->level, msg->text);
            }
            
            default:
            printf("event: %s\n", mpv_event_name(event->event_id));
        }
    }
    
- (void)readEvents
    {
        dispatch_async(queue, ^{
            while (mpv) {
                mpv_event *event = mpv_wait_event(mpv, 0);
                if (event->event_id == MPV_EVENT_NONE)
                {
                    break;
                }
                [self handleEvent:event];
            }
        });
    }
    
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
    {
        _glView.frame = CGRectMake(0, 0, size.width, size.height);
    }
    
    
    @end
