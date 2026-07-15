#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <QuartzCore/CADisplayLink.h>
#import <GameController/GameController.h>
#import <OpenGLES/ES3/gl.h>

#include <ctype.h>
#include <fcntl.h>
#include <unistd.h>

#include "ios/butterscotch_ios.h"
#include "runner_keyboard.h"

static const uint8_t BS_KEY_SOURCE_TOUCH = 1;
static const uint8_t BS_KEY_SOURCE_CONTROLLER = 2;

static const int32_t BS_KEY_ACTION_A = 'Z';
static const int32_t BS_KEY_ACTION_B = 'X';
static const int32_t BS_KEY_ACTION_X = 'C';
static const int32_t BS_KEY_ACTION_Y = 'V';

@interface ButterscotchPassthroughView : UIView
@end

@implementation ButterscotchPassthroughView
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

static NSString* ButterscotchDataDirectory(void) {
    NSString* documentsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsDir stringByAppendingPathComponent:@"Butterscotch"];
}

static NSString* ButterscotchDataWinPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"data.win"];
}

static NSString* ButterscotchInstructionsPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"PLACE_DATA_WIN_HERE.txt"];
}

static NSString* ButterscotchRuntimeLogPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"runtime.log"];
}

static BOOL ShouldDisplayRuntimeLogLine(NSString* line) {
    if (line == nil || line.length == 0) {
        return NO;
    }

    // Hide high-volume noise so errors and GL diagnostics stay visible.
    if ([line hasPrefix:@"Runner: Executing global init script:"]) {
        return NO;
    }
    if ([line hasPrefix:@"VM: Reset complete"]) {
        return NO;
    }

    return YES;
}

static void RedirectStderrToRuntimeLog(void) {
    static BOOL redirected = NO;
    if (redirected) {
        return;
    }

    NSString* path = ButterscotchRuntimeLogPath();
    int fd = open(path.UTF8String, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }

    if (dup2(fd, STDERR_FILENO) == 0) {
        setvbuf(stderr, NULL, _IONBF, 0);
        redirected = YES;
    }
    close(fd);
}

static void EnsureDataDirectoryAndHintFile(void) {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* dirPath = ButterscotchDataDirectory();
    NSError* error = nil;

    if (![fileManager fileExistsAtPath:dirPath]) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Could not create data directory %@: %@", dirPath, error);
            error = nil;
        }
    }

    NSString* hintPath = ButterscotchInstructionsPath();
    if (![fileManager fileExistsAtPath:hintPath]) {
        NSString* hint = @"Place your GameMaker data.win file in this folder and relaunch Butterscotch.\nExpected filename: data.win\n";
        [hint writeToFile:hintPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error != nil) {
            NSLog(@"Could not write hint file %@: %@", hintPath, error);
        }
    }
}

@interface ButterscotchGameViewController : GLKViewController <UITextFieldDelegate>
@property(strong, nonatomic) UILabel* statusLabel;
@property(strong, nonatomic) UIButton* menuButton;
@property(strong, nonatomic) UITextView* debugTextView;
@property(strong, nonatomic) UIView* controlsContainer;
@property(strong, nonatomic) GLKView* gameView;
@property(strong, nonatomic) EAGLContext* glContext;
@property(strong, nonatomic) CADisplayLink* displayLink;
@property(strong, nonatomic) UITextField* keyboardField;
@property(strong, nonatomic) NSMutableArray<NSString*>* debugLines;
@property(assign, nonatomic) BOOL runnerStarted;
@property(assign, nonatomic) CFTimeInterval previousTimestamp;
@property(assign, nonatomic) BOOL mouseDown;
@property(assign, nonatomic) BOOL logVisible;
@property(assign, nonatomic) BOOL keyboardVisible;
@property(assign, nonatomic) BOOL sawNoPresentResult;
@property(assign, nonatomic) BOOL sawFirstDrawCallback;
@property(assign, nonatomic) uint64_t hostFrameCounter;
@property(assign, nonatomic) uint64_t displayLinkTickCounter;
@property(assign, nonatomic) unsigned long long runtimeLogOffset;
@property(assign, nonatomic) BOOL preferNintendoFaceSwap;
@property(strong, nonatomic) NSLayoutConstraint* gameViewLeadingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTrailingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTopConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewBottomConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewPortraitHeightConstraint;
- (void)appendDebugLine:(NSString*)line;
- (void)setupVirtualControls;
- (void)rebuildOptionsMenu;
- (void)setVirtualKey:(int32_t)keyCode source:(uint8_t)source down:(BOOL)down;
- (void)updateControllerInputState;
- (int32_t)mappedActionKeyForLogicalA;
- (int32_t)mappedActionKeyForLogicalB;
- (int32_t)mappedActionKeyForLogicalX;
- (int32_t)mappedActionKeyForLogicalY;
- (void)updateGameViewLayoutForCurrentOrientation;
- (void)pollRuntimeLog;
- (void)attemptStartRunner;
- (void)refreshStatus;
@end

@implementation ButterscotchGameViewController
{
    uint8_t _keySourceMask[GML_KEY_COUNT];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    self.preferredFramesPerSecond = 60;
    self.runnerStarted = NO;
    self.mouseDown = NO;
    self.sawNoPresentResult = NO;
    self.sawFirstDrawCallback = NO;
    self.hostFrameCounter = 0;
    self.displayLinkTickCounter = 0;
    self.runtimeLogOffset = 0;
    self.logVisible = NO;
    self.keyboardVisible = NO;
    self.preferNintendoFaceSwap = NO;
    self.debugLines = [NSMutableArray array];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLinkTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onControllerConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onControllerDisconnected:) name:GCControllerDidDisconnectNotification object:nil];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.menuButton setTitle:@"..." forState:UIControlStateNormal];
    self.menuButton.titleLabel.font = [UIFont monospacedSystemFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.menuButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    self.menuButton.layer.cornerRadius = 8.0;
    self.menuButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [self.view addSubview:self.menuButton];
    [self rebuildOptionsMenu];

    self.debugTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.debugTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.debugTextView.editable = NO;
    self.debugTextView.selectable = YES;
    self.debugTextView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    self.debugTextView.textColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.78 alpha:1.0];
    self.debugTextView.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    self.debugTextView.text = @"[debug] waiting for runtime logs...";
    self.debugTextView.layer.cornerRadius = 8.0;
    self.debugTextView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.debugTextView.hidden = !self.logVisible;
    [self.view addSubview:self.debugTextView];

    self.keyboardField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.keyboardField.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyboardField.delegate = self;
    self.keyboardField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyboardField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyboardField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.keyboardField.keyboardType = UIKeyboardTypeDefault;
    self.keyboardField.returnKeyType = UIReturnKeyDefault;
    self.keyboardField.hidden = YES;
    [self.view addSubview:self.keyboardField];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.93 blue:0.97 alpha:1.0];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightRegular];
    self.statusLabel.textAlignment = NSTextAlignmentLeft;
    self.statusLabel.text = @"Preparing Butterscotch...";

    [self.view addSubview:self.statusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.menuButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [self.menuButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.menuButton.leadingAnchor constant:-12.0],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],

        [self.debugTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [self.debugTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [self.debugTextView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
        [self.debugTextView.heightAnchor constraintEqualToConstant:170.0],

        [self.keyboardField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-200.0],
        [self.keyboardField.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-200.0],
        [self.keyboardField.widthAnchor constraintEqualToConstant:1.0],
        [self.keyboardField.heightAnchor constraintEqualToConstant:1.0],
    ]];

    [self setupVirtualControls];

    [self appendDebugLine:[NSString stringWithFormat:@"[host] data folder: %@", ButterscotchDataDirectory()]];
    [self appendDebugLine:[NSString stringWithFormat:@"[host] runtime log: %@", ButterscotchRuntimeLogPath()]];
    [self attemptStartRunner];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.displayLink invalidate];
    self.displayLink = nil;

    if (self.runnerStarted) {
        ButterscotchIOS_stopRunner();
        self.runnerStarted = NO;
    }
    if ([EAGLContext currentContext] == self.glContext) {
        [EAGLContext setCurrentContext:nil];
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)appendDebugLine:(NSString*)line {
    if (line == nil || line.length == 0) {
        return;
    }

    NSString* stamped = [NSString stringWithFormat:@"%@", line];
    [self.debugLines addObject:stamped];
    if (self.debugLines.count > 220) {
        [self.debugLines removeObjectsInRange:NSMakeRange(0, self.debugLines.count - 220)];
    }

    self.debugTextView.text = [self.debugLines componentsJoinedByString:@"\n"];
    if (self.debugTextView.text.length > 0) {
        NSRange bottom = NSMakeRange(self.debugTextView.text.length - 1, 1);
        [self.debugTextView scrollRangeToVisible:bottom];
    }
}

- (void)setupVirtualControls {
    self.controlsContainer = [[ButterscotchPassthroughView alloc] initWithFrame:CGRectZero];
    self.controlsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlsContainer.userInteractionEnabled = YES;
    self.controlsContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.controlsContainer];

    UIView* dpad = [[UIView alloc] initWithFrame:CGRectZero];
    dpad.translatesAutoresizingMaskIntoConstraints = NO;
    dpad.backgroundColor = [UIColor clearColor];
    [self.controlsContainer addSubview:dpad];

    UIView* abxy = [[UIView alloc] initWithFrame:CGRectZero];
    abxy.translatesAutoresizingMaskIntoConstraints = NO;
    abxy.backgroundColor = [UIColor clearColor];
    [self.controlsContainer addSubview:abxy];

    UIButton* up = [self controlButtonWithTitle:@"^" keyCode:VK_UP];
    UIButton* down = [self controlButtonWithTitle:@"v" keyCode:VK_DOWN];
    UIButton* left = [self controlButtonWithTitle:@"<" keyCode:VK_LEFT];
    UIButton* right = [self controlButtonWithTitle:@">" keyCode:VK_RIGHT];

    UIButton* a = [self controlButtonWithTitle:@"A" keyCode:BS_KEY_ACTION_A];
    UIButton* b = [self controlButtonWithTitle:@"B" keyCode:BS_KEY_ACTION_B];
    UIButton* x = [self controlButtonWithTitle:@"X" keyCode:BS_KEY_ACTION_X];
    UIButton* y = [self controlButtonWithTitle:@"Y" keyCode:BS_KEY_ACTION_Y];

    for (UIButton* button in @[up, down, left, right]) {
        [dpad addSubview:button];
    }
    for (UIButton* button in @[a, b, x, y]) {
        [abxy addSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.controlsContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.controlsContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.controlsContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.controlsContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [dpad.leadingAnchor constraintEqualToAnchor:self.controlsContainer.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [dpad.bottomAnchor constraintEqualToAnchor:self.controlsContainer.safeAreaLayoutGuide.bottomAnchor constant:-16.0],
        [dpad.widthAnchor constraintEqualToConstant:180.0],
        [dpad.heightAnchor constraintEqualToConstant:180.0],

        [abxy.trailingAnchor constraintEqualToAnchor:self.controlsContainer.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [abxy.bottomAnchor constraintEqualToAnchor:self.controlsContainer.safeAreaLayoutGuide.bottomAnchor constant:-16.0],
        [abxy.widthAnchor constraintEqualToConstant:180.0],
        [abxy.heightAnchor constraintEqualToConstant:180.0],

        [up.centerXAnchor constraintEqualToAnchor:dpad.centerXAnchor],
        [up.topAnchor constraintEqualToAnchor:dpad.topAnchor],

        [down.centerXAnchor constraintEqualToAnchor:dpad.centerXAnchor],
        [down.bottomAnchor constraintEqualToAnchor:dpad.bottomAnchor],

        [left.leadingAnchor constraintEqualToAnchor:dpad.leadingAnchor],
        [left.centerYAnchor constraintEqualToAnchor:dpad.centerYAnchor],

        [right.trailingAnchor constraintEqualToAnchor:dpad.trailingAnchor],
        [right.centerYAnchor constraintEqualToAnchor:dpad.centerYAnchor],

        [y.centerXAnchor constraintEqualToAnchor:abxy.centerXAnchor],
        [y.topAnchor constraintEqualToAnchor:abxy.topAnchor],

        [a.centerXAnchor constraintEqualToAnchor:abxy.centerXAnchor],
        [a.bottomAnchor constraintEqualToAnchor:abxy.bottomAnchor],

        [x.leadingAnchor constraintEqualToAnchor:abxy.leadingAnchor],
        [x.centerYAnchor constraintEqualToAnchor:abxy.centerYAnchor],

        [b.trailingAnchor constraintEqualToAnchor:abxy.trailingAnchor],
        [b.centerYAnchor constraintEqualToAnchor:abxy.centerYAnchor],
    ]];
}

- (UIButton*)controlButtonWithTitle:(NSString*)title keyCode:(int32_t)keyCode {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightHeavy];
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.65];
    [button setTitleColor:[UIColor colorWithWhite:0.95 alpha:1.0] forState:UIControlStateNormal];
    button.layer.cornerRadius = 18.0;
    button.tag = keyCode;

    [button addTarget:self action:@selector(onControlButtonDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(onControlButtonDown:) forControlEvents:UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(onControlButtonUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(onControlButtonUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(onControlButtonUp:) forControlEvents:UIControlEventTouchCancel];
    [button addTarget:self action:@selector(onControlButtonUp:) forControlEvents:UIControlEventTouchDragExit];

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:64.0],
        [button.heightAnchor constraintEqualToConstant:64.0],
    ]];
    return button;
}

- (int32_t)mappedActionKeyForLogicalA {
    return self.preferNintendoFaceSwap ? BS_KEY_ACTION_B : BS_KEY_ACTION_A;
}

- (int32_t)mappedActionKeyForLogicalB {
    return self.preferNintendoFaceSwap ? BS_KEY_ACTION_A : BS_KEY_ACTION_B;
}

- (int32_t)mappedActionKeyForLogicalX {
    return self.preferNintendoFaceSwap ? BS_KEY_ACTION_Y : BS_KEY_ACTION_X;
}

- (int32_t)mappedActionKeyForLogicalY {
    return self.preferNintendoFaceSwap ? BS_KEY_ACTION_X : BS_KEY_ACTION_Y;
}

- (void)onControlButtonDown:(UIButton*)sender {
    [self setVirtualKey:(int32_t) sender.tag source:BS_KEY_SOURCE_TOUCH down:YES];
}

- (void)onControlButtonUp:(UIButton*)sender {
    [self setVirtualKey:(int32_t) sender.tag source:BS_KEY_SOURCE_TOUCH down:NO];
}

- (void)setVirtualKey:(int32_t)keyCode source:(uint8_t)source down:(BOOL)down {
    if (keyCode < 0 || keyCode >= GML_KEY_COUNT) {
        return;
    }

    uint8_t before = _keySourceMask[keyCode];
    uint8_t after = down ? (uint8_t) (before | source) : (uint8_t) (before & (uint8_t) ~source);
    if (before == after) {
        return;
    }

    _keySourceMask[keyCode] = after;
    BOOL wasDown = before != 0;
    BOOL isDown = after != 0;

    if (!wasDown && isDown) {
        ButterscotchIOS_onKeyDown(keyCode);
    } else if (wasDown && !isDown) {
        ButterscotchIOS_onKeyUp(keyCode);
    }
}

- (void)updateControllerInputState {
    BOOL wantLeft = NO;
    BOOL wantRight = NO;
    BOOL wantUp = NO;
    BOOL wantDown = NO;
    BOOL wantA = NO;
    BOOL wantB = NO;
    BOOL wantX = NO;
    BOOL wantY = NO;
    BOOL wantEnter = NO;

    NSArray<GCController*>* controllers = [GCController controllers];
    for (GCController* controller in controllers) {
        GCExtendedGamepad* gamepad = controller.extendedGamepad;
        if (gamepad != nil) {
            wantLeft |= gamepad.dpad.left.isPressed;
            wantRight |= gamepad.dpad.right.isPressed;
            wantUp |= gamepad.dpad.up.isPressed;
            wantDown |= gamepad.dpad.down.isPressed;

            wantA |= gamepad.buttonA.isPressed;
            wantB |= gamepad.buttonB.isPressed;
            wantX |= gamepad.buttonX.isPressed;
            wantY |= gamepad.buttonY.isPressed;

            if (@available(iOS 14.0, *)) {
                wantEnter |= gamepad.buttonMenu.isPressed;
            }
            continue;
        }

        GCMicroGamepad* micro = controller.microGamepad;
        if (micro != nil) {
            wantLeft |= micro.dpad.left.isPressed;
            wantRight |= micro.dpad.right.isPressed;
            wantUp |= micro.dpad.up.isPressed;
            wantDown |= micro.dpad.down.isPressed;

            wantA |= micro.buttonA.isPressed;
            wantB |= micro.buttonX.isPressed;
        }
    }

    [self setVirtualKey:VK_LEFT source:BS_KEY_SOURCE_CONTROLLER down:wantLeft];
    [self setVirtualKey:VK_RIGHT source:BS_KEY_SOURCE_CONTROLLER down:wantRight];
    [self setVirtualKey:VK_UP source:BS_KEY_SOURCE_CONTROLLER down:wantUp];
    [self setVirtualKey:VK_DOWN source:BS_KEY_SOURCE_CONTROLLER down:wantDown];

    [self setVirtualKey:[self mappedActionKeyForLogicalA] source:BS_KEY_SOURCE_CONTROLLER down:wantA];
    [self setVirtualKey:[self mappedActionKeyForLogicalB] source:BS_KEY_SOURCE_CONTROLLER down:wantB];
    [self setVirtualKey:[self mappedActionKeyForLogicalX] source:BS_KEY_SOURCE_CONTROLLER down:wantX];
    [self setVirtualKey:[self mappedActionKeyForLogicalY] source:BS_KEY_SOURCE_CONTROLLER down:wantY];
    [self setVirtualKey:VK_ENTER source:BS_KEY_SOURCE_CONTROLLER down:wantEnter];
}

- (void)rebuildOptionsMenu {
    if (@available(iOS 14.0, *)) {
        __unsafe_unretained typeof(self) weakSelf = self;
        UIAction* refreshAction = [UIAction actionWithTitle:@"Refresh" image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            [weakSelf onRefreshTapped];
        }];

        NSString* logTitle = self.logVisible ? @"Hide Log" : @"Show Log";
        UIAction* logAction = [UIAction actionWithTitle:logTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            weakSelf.logVisible = !weakSelf.logVisible;
            weakSelf.debugTextView.hidden = !weakSelf.logVisible;
            [weakSelf appendDebugLine:[NSString stringWithFormat:@"[host] log %@", weakSelf.logVisible ? @"shown" : @"hidden"]];
            [weakSelf rebuildOptionsMenu];
        }];

        NSString* keyboardTitle = self.keyboardVisible ? @"Hide Keyboard" : @"Show Keyboard";
        UIAction* keyboardAction = [UIAction actionWithTitle:keyboardTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            if (weakSelf.keyboardVisible) {
                [weakSelf.keyboardField resignFirstResponder];
                weakSelf.keyboardVisible = NO;
            } else {
                [weakSelf.keyboardField becomeFirstResponder];
                weakSelf.keyboardVisible = YES;
            }
            [weakSelf appendDebugLine:[NSString stringWithFormat:@"[host] onscreen keyboard %@", weakSelf.keyboardVisible ? @"shown" : @"hidden"]];
            [weakSelf rebuildOptionsMenu];
        }];

        NSString* swapTitle = self.preferNintendoFaceSwap ? @"Nintendo A/B + X/Y: On" : @"Nintendo A/B + X/Y: Off";
        UIAction* swapAction = [UIAction actionWithTitle:swapTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            weakSelf.preferNintendoFaceSwap = !weakSelf.preferNintendoFaceSwap;
            [weakSelf appendDebugLine:[NSString stringWithFormat:@"[host] nintendo face swap %@", weakSelf.preferNintendoFaceSwap ? @"enabled" : @"disabled"]];
            [weakSelf rebuildOptionsMenu];
        }];

        self.menuButton.menu = [UIMenu menuWithTitle:@"" children:@[refreshAction, logAction, keyboardAction, swapAction]];
        self.menuButton.showsMenuAsPrimaryAction = YES;
    }
}

- (void)onControllerConnected:(NSNotification*)notification {
    (void) notification;
    [self appendDebugLine:@"[host] bluetooth controller connected"]; 
}

- (void)onControllerDisconnected:(NSNotification*)notification {
    (void) notification;
    [self appendDebugLine:@"[host] bluetooth controller disconnected"]; 
}

- (void)pollRuntimeLog {
    NSString* logPath = ButterscotchRuntimeLogPath();
    NSData* data = [NSData dataWithContentsOfFile:logPath];
    if (data == nil) {
        return;
    }

    unsigned long long length = (unsigned long long) data.length;
    if (length < self.runtimeLogOffset) {
        self.runtimeLogOffset = 0;
    }
    if (length == self.runtimeLogOffset) {
        return;
    }

    NSUInteger start = (NSUInteger) self.runtimeLogOffset;
    NSUInteger deltaLen = (NSUInteger) (length - self.runtimeLogOffset);
    NSData* delta = [data subdataWithRange:NSMakeRange(start, deltaLen)];
    self.runtimeLogOffset = length;

    NSString* chunk = [[NSString alloc] initWithData:delta encoding:NSUTF8StringEncoding];
    if (chunk == nil) {
        chunk = [[NSString alloc] initWithData:delta encoding:NSASCIIStringEncoding];
    }
    if (chunk.length == 0) {
        return;
    }

    NSArray<NSString*>* lines = [chunk componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger suppressedCount = 0;
    for (NSString* line in lines) {
        NSString* trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            continue;
        }
        if (!ShouldDisplayRuntimeLogLine(trimmed)) {
            suppressedCount += 1;
            continue;
        }
        [self appendDebugLine:[NSString stringWithFormat:@"[stderr] %@", trimmed]];
    }
    if (suppressedCount > 0) {
        [self appendDebugLine:[NSString stringWithFormat:@"[stderr] ... %lu noisy lines hidden", (unsigned long) suppressedCount]];
    }
}

- (void)attemptStartRunner {
    EnsureDataDirectoryAndHintFile();
    RedirectStderrToRuntimeLog();
    [self pollRuntimeLog];

    NSString* dataWinPath = ButterscotchDataWinPath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataWinPath]) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] missing data.win at %@", dataWinPath]];
        [self refreshStatus];
        return;
    }

    [self appendDebugLine:[NSString stringWithFormat:@"[host] attempting runner start with %@", dataWinPath]];

    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (self.glContext == nil) {
        self.statusLabel.text = @"Failed to create OpenGL ES 3 context.";
        [self appendDebugLine:@"[host] failed to create OpenGL ES 3 context"]; 
        return;
    }

    if (self.gameView == nil) {
        self.gameView = [[GLKView alloc] initWithFrame:self.view.bounds context:self.glContext];
        self.gameView.translatesAutoresizingMaskIntoConstraints = NO;
        self.gameView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
        self.gameView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
        self.gameView.enableSetNeedsDisplay = YES;
        self.gameView.multipleTouchEnabled = YES;
        self.gameView.delegate = self;

        [self.view insertSubview:self.gameView atIndex:0];
        self.gameViewLeadingConstraint = [self.gameView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor];
        self.gameViewTrailingConstraint = [self.gameView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor];
        self.gameViewTopConstraint = [self.gameView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:0.0];
        self.gameViewBottomConstraint = [self.gameView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
        self.gameViewPortraitHeightConstraint = [self.gameView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.56];
        [NSLayoutConstraint activateConstraints:@[
            self.gameViewLeadingConstraint,
            self.gameViewTrailingConstraint,
            self.gameViewTopConstraint,
            self.gameViewBottomConstraint,
        ]];
        [self updateGameViewLayoutForCurrentOrientation];
    } else {
        self.gameView.context = self.glContext;
        [self updateGameViewLayoutForCurrentOrientation];
    }

    [EAGLContext setCurrentContext:self.glContext];

    NSString* savesPath = [ButterscotchDataDirectory() stringByAppendingPathComponent:@"saves"];
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:savesPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        NSLog(@"Could not create saves directory %@: %@", savesPath, error);
        [self appendDebugLine:[NSString stringWithFormat:@"[host] failed to create saves dir: %@", error.localizedDescription]];
    }

    [self.gameView bindDrawable];
    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);
    [self appendDebugLine:[NSString stringWithFormat:@"[gl] startup framebuffer binding: %d", (int) hostFramebuffer]];

    BOOL started = ButterscotchIOS_startRunner(dataWinPath.UTF8String, savesPath.UTF8String, BS_IOS_OS_IOS, (uint32_t) hostFramebuffer);
    [self pollRuntimeLog];
    if (!started) {
        self.statusLabel.text = @"Found data.win, but runner failed to start.";
        [self appendDebugLine:@"[host] ButterscotchIOS_startRunner returned false"]; 
        return;
    }

    self.runnerStarted = YES;
    self.sawNoPresentResult = NO;
    self.sawFirstDrawCallback = NO;
    self.hostFrameCounter = 0;
    self.displayLinkTickCounter = 0;
    self.previousTimestamp = 0.0;
    self.statusLabel.hidden = YES;
    [self appendDebugLine:@"[host] runner started"]; 

    int32_t targetHz = ButterscotchIOS_getTargetFrameHz();
    if (targetHz > 10 && targetHz <= 240) {
        self.preferredFramesPerSecond = targetHz;
    }
    [self appendDebugLine:[NSString stringWithFormat:@"[host] target fps: %ld", (long) self.preferredFramesPerSecond]];

    if (self.preferredFramesPerSecond > 0) {
        self.displayLink.preferredFramesPerSecond = self.preferredFramesPerSecond;
    }
}

- (void)refreshStatus {
    self.statusLabel.hidden = NO;
    self.statusLabel.text = [NSString stringWithFormat:
        @"Butterscotch iOS\n\n"
         "No data.win found.\n\n"
         "Open Files > On My iPhone/iPad > Butterscotch\n"
         "and copy your game file there as data.win, then tap Refresh.\n\n"
         "Folder:\n%@",
        ButterscotchDataDirectory()];
}

- (void)onRefreshTapped {
    [self appendDebugLine:@"[host] manual refresh tapped"]; 
    [self pollRuntimeLog];

    if (self.runnerStarted) {
        ButterscotchIOS_stopRunner();
        self.runnerStarted = NO;
        self.previousTimestamp = 0.0;
        for (int32_t i = 0; i < GML_KEY_COUNT; i++) {
            _keySourceMask[i] = 0;
        }
        [self appendDebugLine:@"[host] previous runner stopped"]; 
    }

    [self attemptStartRunner];
    [self pollRuntimeLog];
}

- (void)onDisplayLinkTick:(CADisplayLink*)link {
    (void) link;
    if (self.gameView == nil) {
        return;
    }

    self.displayLinkTickCounter += 1;
    if (self.displayLinkTickCounter % 120 == 0) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] display tick %llu", self.displayLinkTickCounter]];
    }

    if (self.runnerStarted) {
        [self updateControllerInputState];
    }

    [self.gameView setNeedsDisplay];
    [self.gameView display];
}

- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
    (void) rect;

    if (!self.runnerStarted) {
        [self pollRuntimeLog];
        [self refreshStatus];
        return;
    }

    self.hostFrameCounter += 1;
    if (!self.sawFirstDrawCallback) {
        self.sawFirstDrawCallback = YES;
        [self appendDebugLine:[NSString stringWithFormat:@"[host] first draw callback (%d x %d)", (int) view.drawableWidth, (int) view.drawableHeight]];
    }

    CFTimeInterval now = CACurrentMediaTime();
    float dt = 1.0f / (float) self.preferredFramesPerSecond;
    if (self.previousTimestamp > 0.0) {
        dt = (float) (now - self.previousTimestamp);
    }
    self.previousTimestamp = now;

    [EAGLContext setCurrentContext:self.glContext];
    [view bindDrawable];

    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);
    ButterscotchIOS_setHostFramebuffer((uint32_t) hostFramebuffer);

    ButterscotchIOS_beginFrame();
    int32_t result = ButterscotchIOS_stepAndDraw((int32_t) (view.drawableWidth), (int32_t) (view.drawableHeight), dt);
    [self pollRuntimeLog];

    if (self.hostFrameCounter % 120 == 0) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] frame %llu result=%d size=%dx%d", self.hostFrameCounter, (int) result, (int) view.drawableWidth, (int) view.drawableHeight]];
    }

    GLenum glErr = glGetError();
    if (glErr != GL_NO_ERROR) {
        [self appendDebugLine:[NSString stringWithFormat:@"[gl] glGetError = 0x%04x", (unsigned int) glErr]];
    }

    if (result == BS_IOS_CONTINUE_NO_PRESENT && !self.sawNoPresentResult) {
        self.sawNoPresentResult = YES;
        [self appendDebugLine:@"[host] frame returned CONTINUE_NO_PRESENT"]; 
    }

    if (result == BS_IOS_SHOULD_EXIT) {
        [self appendDebugLine:@"[host] runner requested exit"]; 
        ButterscotchIOS_stopRunner();
        self.runnerStarted = NO;
        for (int32_t i = 0; i < GML_KEY_COUNT; i++) {
            _keySourceMask[i] = 0;
        }
        [self refreshStatus];
    }
}

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string {
    (void) textField;

    if (!self.runnerStarted) {
        return NO;
    }

    if (string.length == 0 && range.length > 0) {
        ButterscotchIOS_onKeyDown(VK_BACKSPACE);
        ButterscotchIOS_onKeyUp(VK_BACKSPACE);
        return NO;
    }

    NSUInteger length = string.length;
    for (NSUInteger i = 0; i < length; i++) {
        unichar ch = [string characterAtIndex:i];
        if (ch == 0) {
            continue;
        }

        if (ch < 128) {
            int32_t keyCode = (int32_t) ch;
            if ('a' <= ch && ch <= 'z') {
                keyCode = (int32_t) toupper((int) ch);
            }
            ButterscotchIOS_onKeyDown(keyCode);
            ButterscotchIOS_onKeyUp(keyCode);
        }

        ButterscotchIOS_onCharacter((uint32_t) ch);
    }

    return NO;
}

- (void)updateMouseFromTouch:(UITouch*)touch inView:(UIView*)view {
    UIView* targetView = self.gameView != nil ? self.gameView : view;
    CGPoint point = [touch locationInView:targetView];
    CGSize size = targetView.bounds.size;
    if (size.width <= 0.0 || size.height <= 0.0) return;

    float normalizedX = (float) (point.x / size.width);
    float normalizedY = (float) (point.y / size.height);
    ButterscotchIOS_setNormalizedCursorPosition(normalizedX, normalizedY);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateGameViewLayoutForCurrentOrientation];
}

- (void)updateGameViewLayoutForCurrentOrientation {
    if (self.gameView == nil || self.gameViewTopConstraint == nil || self.gameViewBottomConstraint == nil || self.gameViewPortraitHeightConstraint == nil) {
        return;
    }

    BOOL isPortrait = self.view.bounds.size.height > self.view.bounds.size.width;
    self.gameViewBottomConstraint.active = !isPortrait;
    self.gameViewPortraitHeightConstraint.active = isPortrait;
    self.gameViewTopConstraint.constant = isPortrait ? 8.0 : 0.0;
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) event;
    if (!self.runnerStarted) return;
    UITouch* touch = touches.anyObject;
    if (touch == nil) return;
    [self updateMouseFromTouch:touch inView:self.view];
    self.mouseDown = YES;
    ButterscotchIOS_setMouseButtonState(0, true);
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) event;
    if (!self.runnerStarted) return;
    UITouch* touch = touches.anyObject;
    if (touch == nil) return;
    [self updateMouseFromTouch:touch inView:self.view];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) touches;
    (void) event;
    if (!self.runnerStarted) return;
    self.mouseDown = NO;
    ButterscotchIOS_setMouseButtonState(0, false);
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) touches;
    (void) event;
    if (!self.runnerStarted) return;
    self.mouseDown = NO;
    ButterscotchIOS_setMouseButtonState(0, false);
}

@end

@interface ButterscotchAppDelegate : UIResponder <UIApplicationDelegate>
@property(strong, nonatomic) UIWindow* window;
@end

@implementation ButterscotchAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void) application;
    (void) launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    ButterscotchGameViewController* root = [ButterscotchGameViewController new];

    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application {
    (void) application;
    ButterscotchIOS_suspendAudio();
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    (void) application;
    ButterscotchIOS_suspendAudio();
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
    (void) application;
    ButterscotchIOS_resumeAudio();
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
    (void) application;
    ButterscotchIOS_resumeAudio();
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ButterscotchAppDelegate class]));
    }
}
