#import "ipa_game_view_controller.h"
#import "ipa_settings.h"

#import <AVFoundation/AVFoundation.h>
#import <GameController/GameController.h>
#import <QuartzCore/CADisplayLink.h>
#import <OpenGLES/ES3/gl.h>

#include <stdatomic.h>

#include "ios/butterscotch_ios.h"
#include "ios/ipa_support.h"
#include "runner_keyboard.h"

static const uint8_t BS_KEY_SOURCE_TOUCH = 1;
static const uint8_t BS_KEY_SOURCE_CONTROLLER = 2;

static const NSTimeInterval BS_MENU_AUTO_HIDE_SECONDS = 3.0;

static const int32_t BS_KEY_ACTION_A = 'Z';
static const int32_t BS_KEY_ACTION_B = 'X';
static const int32_t BS_KEY_ACTION_X = 'C';
static const int32_t BS_KEY_ACTION_Y = 'V';
static const CFTimeInterval BS_VIDEO_STALL_TIMEOUT_SECONDS = 2.0;
static const CFTimeInterval BS_VIDEO_MIN_WATCHDOG_DELAY_SECONDS = 1.0;
static const CFTimeInterval BS_VIDEO_HARD_TIMEOUT_SECONDS = 45.0;

static __unsafe_unretained ButterscotchGameViewController* gActiveGameController = nil;
static _Atomic(bool) gIOSVideoIsOpen = false;
static _Atomic(bool) gIOSVideoIsPlaying = false;

@interface ButterscotchGameViewController ()
@property(strong, nonatomic) UILabel* statusLabel;
@property(strong, nonatomic) UIButton* menuButton;
@property(strong, nonatomic) UIButton* fastForwardButton;
@property(strong, nonatomic) UIView* controlsContainer;
@property(strong, nonatomic) GLKView* gameView;
@property(strong, nonatomic) EAGLContext* glContext;
@property(strong, nonatomic) CADisplayLink* displayLink;
@property(assign, nonatomic) BOOL runnerStarted;
@property(assign, nonatomic) BOOL mouseDown;
@property(assign, nonatomic) BOOL controlsVisible;
@property(assign, nonatomic) BOOL sawNoPresentResult;
@property(assign, nonatomic) BOOL sawFirstDrawCallback;
@property(assign, nonatomic) uint64_t hostFrameCounter;
@property(assign, nonatomic) uint64_t displayLinkTickCounter;
@property(assign, nonatomic) float fixedStepDeltaSeconds;
@property(assign, nonatomic) float accumulatedDisplaySeconds;
@property(assign, nonatomic) float pendingFrameDeltaSeconds;
@property(assign, nonatomic) NSInteger pendingSimulationSteps;
@property(assign, nonatomic) CFTimeInterval lastDisplayLinkTimestamp;
@property(assign, nonatomic) BOOL preferNintendoFaceSwap;
@property(strong, nonatomic) NSTimer* menuAutoHideTimer;
@property(assign, nonatomic) BOOL sessionPaused;
@property(assign, nonatomic) BOOL fastForwardEnabled;
@property(strong, nonatomic) AVPlayer* videoPlayer;
@property(strong, nonatomic) AVPlayerLayer* videoLayer;
@property(strong, nonatomic) id videoEndObserver;
@property(strong, nonatomic) id videoTimeObserver;
@property(assign, nonatomic) BOOL videoLoopEnabled;
@property(assign, nonatomic) float videoVolume;
@property(assign, nonatomic) BOOL videoPausedByScript;
@property(assign, nonatomic) BOOL videoClosePending;
@property(assign, nonatomic) CFTimeInterval videoLastProgressHostTime;
@property(assign, nonatomic) double videoLastProgressSeconds;
@property(assign, nonatomic) CFTimeInterval videoOpenedHostTime;
@property(strong, nonatomic) NSLayoutConstraint* gameViewLeadingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTrailingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTopConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewBottomConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewPortraitHeightConstraint;
@end

@implementation ButterscotchGameViewController
{
    uint8_t _keySourceMask[GML_KEY_COUNT];
}

- (instancetype)initWithLaunchInfo:(NSDictionary<NSString*, NSString*>*)launchInfo {
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil) {
        self.launchKey = launchInfo[@"key"];
        self.launchTitle = launchInfo[@"title"];
        self.launchRelativeDataWinPath = launchInfo[@"relative"];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    self.preferredFramesPerSecond = 60;
    self.paused = YES;

    self.runnerStarted = NO;
    self.mouseDown = NO;
    self.sawNoPresentResult = NO;
    self.sawFirstDrawCallback = NO;
    self.hostFrameCounter = 0;
    self.displayLinkTickCounter = 0;
    self.fixedStepDeltaSeconds = 1.0f / 60.0f;
    self.accumulatedDisplaySeconds = 0.0f;
    self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    self.pendingSimulationSteps = 1;
    self.lastDisplayLinkTimestamp = 0.0;
    self.controlsVisible = NO;
    self.sessionPaused = YES;
    self.fastForwardEnabled = NO;
    self.videoLoopEnabled = NO;
    self.videoVolume = 1.0f;
    self.videoPausedByScript = NO;
    self.videoClosePending = NO;
    self.videoLastProgressHostTime = 0.0;
    self.videoLastProgressSeconds = 0.0;
    self.videoOpenedHostTime = 0.0;
    self.preferNintendoFaceSwap = BSLoadNintendoSwap();

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLinkTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onControllerConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onControllerDisconnected:) name:GCControllerDidDisconnectNotification object:nil];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
    self.menuButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.menuButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    self.menuButton.layer.cornerRadius = 8.0;
    self.menuButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [self.view addSubview:self.menuButton];

    self.fastForwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.fastForwardButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fastForwardButton setTitle:@"FF" forState:UIControlStateNormal];
    self.fastForwardButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    self.fastForwardButton.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    [self.fastForwardButton setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    self.fastForwardButton.layer.cornerRadius = 8.0;
    self.fastForwardButton.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
    [self.fastForwardButton addTarget:self action:@selector(onFastForwardTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.fastForwardButton];
    [self updateFastForwardButtonAppearance];

    [self rebuildOptionsMenu];
    [self registerUserInteraction];

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

        [self.fastForwardButton.trailingAnchor constraintEqualToAnchor:self.menuButton.leadingAnchor constant:-8.0],
        [self.fastForwardButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.fastForwardButton.leadingAnchor constant:-12.0],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
    ]];

    [self setupVirtualControls];

    [self appendDebugLine:[NSString stringWithFormat:@"[host] launch: %@", self.launchTitle]];
    [self appendDebugLine:[NSString stringWithFormat:@"[host] data folder: %@", ButterscotchDataDirectory()]];
    [self attemptStartRunner];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.displayLink invalidate];
    self.displayLink = nil;

    [self.menuAutoHideTimer invalidate];
    self.menuAutoHideTimer = nil;

    if (self.videoEndObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.videoEndObserver];
        self.videoEndObserver = nil;
    }
    if (self.videoPlayer != nil && self.videoTimeObserver != nil) {
        [self.videoPlayer removeTimeObserver:self.videoTimeObserver];
        self.videoTimeObserver = nil;
    }
    [self.videoPlayer pause];
    [self.videoLayer removeFromSuperlayer];
    self.videoLayer = nil;
    self.videoPlayer = nil;
    if (gActiveGameController == self) {
        gActiveGameController = nil;
    }

    [self shutdownRunnerSession];

    if ([EAGLContext currentContext] == self.glContext) {
        [EAGLContext setCurrentContext:nil];
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)shutdownRunnerSession {
    [self setSessionPaused:YES];
    if (!self.runnerStarted) {
        return;
    }

    ButterscotchIOS_stopRunner();
    self.runnerStarted = NO;
    self.accumulatedDisplaySeconds = 0.0f;
    self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    self.pendingSimulationSteps = 1;
    self.lastDisplayLinkTimestamp = 0.0;
    [self clearAllVirtualKeys];
}

- (void)setSessionPaused:(BOOL)paused {
    if (_sessionPaused == paused) {
        return;
    }
    _sessionPaused = paused;
    self.paused = paused;
    if (self.displayLink != nil) {
        self.displayLink.paused = paused;
    }

    if (paused) {
        self.lastDisplayLinkTimestamp = 0.0;
        self.accumulatedDisplaySeconds = 0.0f;
        [self clearAllVirtualKeys];
        if (self.mouseDown) {
            self.mouseDown = NO;
            ButterscotchIOS_setMouseButtonState(0, false);
        }
        ButterscotchIOS_suspendAudio();
        [self.videoPlayer pause];
        atomic_store(&gIOSVideoIsPlaying, false);
    } else {
        self.lastDisplayLinkTimestamp = 0.0;
        ButterscotchIOS_resumeAudio();
        if (self.videoPlayer != nil) {
            [self.videoPlayer play];
            atomic_store(&gIOSVideoIsPlaying, true);
        }
    }
}

- (void)clearAllVirtualKeys {
    for (int32_t i = 0; i < GML_KEY_COUNT; i++) {
        if (_keySourceMask[i] != 0) {
            ButterscotchIOS_onKeyUp(i);
            _keySourceMask[i] = 0;
        }
    }
}

- (void)appendDebugLine:(NSString*)line {
    if (line == nil || line.length == 0) {
        return;
    }

    // Mirror all host debug lines to Xcode's console for easier device debugging.
    NSLog(@"%@", line);
    const char* utf8 = [line UTF8String];
    if (utf8 != NULL) {
        fprintf(stdout, "%s\n", utf8);
        fflush(stdout);
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
    [self.controlsContainer addSubview:dpad];

    UIView* abxy = [[UIView alloc] initWithFrame:CGRectZero];
    abxy.translatesAutoresizingMaskIntoConstraints = NO;
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

- (int32_t)mappedActionKeyForLogicalA { return self.preferNintendoFaceSwap ? BS_KEY_ACTION_B : BS_KEY_ACTION_A; }
- (int32_t)mappedActionKeyForLogicalB { return self.preferNintendoFaceSwap ? BS_KEY_ACTION_A : BS_KEY_ACTION_B; }
- (int32_t)mappedActionKeyForLogicalX { return self.preferNintendoFaceSwap ? BS_KEY_ACTION_Y : BS_KEY_ACTION_X; }
- (int32_t)mappedActionKeyForLogicalY { return self.preferNintendoFaceSwap ? BS_KEY_ACTION_X : BS_KEY_ACTION_Y; }

- (void)setDirectionalKeysForArrow:(int32_t)arrow source:(uint8_t)source down:(BOOL)down {
    if (arrow == VK_LEFT) {
        [self setVirtualKey:VK_LEFT source:source down:down];
    } else if (arrow == VK_RIGHT) {
        [self setVirtualKey:VK_RIGHT source:source down:down];
    } else if (arrow == VK_UP) {
        [self setVirtualKey:VK_UP source:source down:down];
    } else if (arrow == VK_DOWN) {
        [self setVirtualKey:VK_DOWN source:source down:down];
    }
}

- (void)onControlButtonDown:(UIButton*)sender {
    [self registerUserInteraction];
    if (sender.selected) {
        return;
    }
    sender.selected = YES;

    int32_t key = (int32_t) sender.tag;
    if (key == VK_LEFT || key == VK_RIGHT || key == VK_UP || key == VK_DOWN) {
        [self setDirectionalKeysForArrow:key source:BS_KEY_SOURCE_TOUCH down:YES];
    } else {
        [self setVirtualKey:key source:BS_KEY_SOURCE_TOUCH down:YES];
    }
}

- (void)onControlButtonUp:(UIButton*)sender {
    [self registerUserInteraction];
    if (!sender.selected) {
        return;
    }
    sender.selected = NO;

    int32_t key = (int32_t) sender.tag;
    if (key == VK_LEFT || key == VK_RIGHT || key == VK_UP || key == VK_DOWN) {
        [self setDirectionalKeysForArrow:key source:BS_KEY_SOURCE_TOUCH down:NO];
    } else {
        [self setVirtualKey:key source:BS_KEY_SOURCE_TOUCH down:NO];
    }
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

        GCGamepad* simpleGamepad = controller.gamepad;
        if (simpleGamepad != nil) {
            wantLeft |= simpleGamepad.dpad.left.isPressed;
            wantRight |= simpleGamepad.dpad.right.isPressed;
            wantUp |= simpleGamepad.dpad.up.isPressed;
            wantDown |= simpleGamepad.dpad.down.isPressed;

            wantA |= simpleGamepad.buttonA.isPressed;
            wantB |= simpleGamepad.buttonB.isPressed;
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

    [self setDirectionalKeysForArrow:VK_LEFT source:BS_KEY_SOURCE_CONTROLLER down:wantLeft];
    [self setDirectionalKeysForArrow:VK_RIGHT source:BS_KEY_SOURCE_CONTROLLER down:wantRight];
    [self setDirectionalKeysForArrow:VK_UP source:BS_KEY_SOURCE_CONTROLLER down:wantUp];
    [self setDirectionalKeysForArrow:VK_DOWN source:BS_KEY_SOURCE_CONTROLLER down:wantDown];

    [self setVirtualKey:[self mappedActionKeyForLogicalA] source:BS_KEY_SOURCE_CONTROLLER down:wantA];
    [self setVirtualKey:[self mappedActionKeyForLogicalB] source:BS_KEY_SOURCE_CONTROLLER down:wantB];
    [self setVirtualKey:[self mappedActionKeyForLogicalX] source:BS_KEY_SOURCE_CONTROLLER down:wantX];
    [self setVirtualKey:[self mappedActionKeyForLogicalY] source:BS_KEY_SOURCE_CONTROLLER down:wantY];
    [self setVirtualKey:VK_ENTER source:BS_KEY_SOURCE_CONTROLLER down:wantEnter];
}

- (void)rebuildOptionsMenu {
    if (@available(iOS 14.0, *)) {
        __unsafe_unretained typeof(self) weakSelf = self;

        UIAction* backAction = [UIAction actionWithTitle:@"Back to library" image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            [weakSelf registerUserInteraction];
            if (weakSelf.delegate != nil) {
                [weakSelf.delegate gameViewControllerDidRequestReturnToLibrary:weakSelf];
            }
        }];

        NSString* controlsTitle = self.controlsVisible ? @"Hide on-screen controller" : @"Show on-screen controller";
        UIAction* controlsAction = [UIAction actionWithTitle:controlsTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            [weakSelf registerUserInteraction];
            weakSelf.controlsVisible = !weakSelf.controlsVisible;
            weakSelf.controlsContainer.hidden = !weakSelf.controlsVisible;
            [weakSelf rebuildOptionsMenu];
        }];

        self.menuButton.menu = [UIMenu menuWithTitle:@"" children:@[
            backAction,
            controlsAction,
        ]];
        self.menuButton.showsMenuAsPrimaryAction = YES;
    }
}

- (void)registerUserInteraction {
    self.menuButton.hidden = NO;
    self.fastForwardButton.hidden = NO;
    [self resetMenuAutoHideTimer];
}

- (void)resetMenuAutoHideTimer {
    [self.menuAutoHideTimer invalidate];
    self.menuAutoHideTimer = [NSTimer scheduledTimerWithTimeInterval:BS_MENU_AUTO_HIDE_SECONDS target:self selector:@selector(onMenuAutoHideTimerFired:) userInfo:nil repeats:NO];
}

- (void)onMenuAutoHideTimerFired:(NSTimer*)timer {
    if (timer != self.menuAutoHideTimer) {
        return;
    }
    self.menuButton.hidden = YES;
    self.fastForwardButton.hidden = YES;
}

- (void)onFastForwardTapped:(UIButton*)sender {
    (void) sender;
    [self registerUserInteraction];
    self.fastForwardEnabled = !self.fastForwardEnabled;
    [self updateFastForwardButtonAppearance];

    NSString* state = self.fastForwardEnabled ? @"enabled" : @"disabled";
    [self appendDebugLine:[NSString stringWithFormat:@"[host] fast-forward %@", state]];
}

- (void)updateFastForwardButtonAppearance {
    UIColor* activeColor = [UIColor colorWithRed:0.20 green:0.48 blue:0.22 alpha:0.92];
    UIColor* inactiveColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    UIColor* activeText = [UIColor colorWithWhite:1.0 alpha:1.0];
    UIColor* inactiveText = [UIColor colorWithWhite:0.85 alpha:1.0];

    self.fastForwardButton.backgroundColor = self.fastForwardEnabled ? activeColor : inactiveColor;
    [self.fastForwardButton setTitleColor:(self.fastForwardEnabled ? activeText : inactiveText) forState:UIControlStateNormal];
}

- (void)onControllerConnected:(NSNotification*)notification { (void) notification; [self registerUserInteraction]; [self appendDebugLine:@"[host] bluetooth controller connected"]; }
- (void)onControllerDisconnected:(NSNotification*)notification { (void) notification; [self registerUserInteraction]; [self appendDebugLine:@"[host] bluetooth controller disconnected"]; }

- (void)attemptStartRunner {
    EnsureDataDirectoryAndHintFile();

    NSString* dataWinPath = ButterscotchPathFromDataDirectory(self.launchRelativeDataWinPath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataWinPath]) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] missing data.win at %@", dataWinPath]];
        [self refreshStatus];
        return;
    }

    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (self.glContext == nil) {
        self.statusLabel.text = @"Failed to create OpenGL ES 3 context.";
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
        self.gameViewPortraitHeightConstraint = [self.gameView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.45];
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

    NSString* savesSubdir = self.launchKey;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^dr_ch\\d" options:0 error:nil];
    if ([regex numberOfMatchesInString:savesSubdir options:0 range:NSMakeRange(0, savesSubdir.length)] > 0) {
        savesSubdir = @"deltarune";
    }

    NSString* savesPath = ButterscotchPathFromDataDirectory([NSString stringWithFormat:@"saves/%@", savesSubdir]);
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:savesPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] failed to create saves dir: %@", error.localizedDescription]];
    }

    [self.gameView bindDrawable];
    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);

    BOOL started = ButterscotchIOS_startRunner(dataWinPath.UTF8String, savesPath.UTF8String, BS_IOS_OS_IOS, (uint32_t) hostFramebuffer);
    if (!started) {
        self.statusLabel.text = @"Found data.win, but runner failed to start.";
        return;
    }

    self.runnerStarted = YES;
    self.sawNoPresentResult = NO;
    self.sawFirstDrawCallback = NO;
    self.hostFrameCounter = 0;
    self.displayLinkTickCounter = 0;
    self.accumulatedDisplaySeconds = 0.0f;
    self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    self.pendingSimulationSteps = 1;
    self.lastDisplayLinkTimestamp = 0.0;
    self.statusLabel.hidden = YES;

    int32_t targetHz = ButterscotchIOS_getTargetFrameHz();
    if (targetHz > 10 && targetHz <= 240) {
        self.preferredFramesPerSecond = targetHz;
        self.fixedStepDeltaSeconds = 1.0f / (float) targetHz;
    } else {
        self.fixedStepDeltaSeconds = 1.0f / 60.0f;
    }

    if (self.preferredFramesPerSecond > 0) {
        self.displayLink.preferredFramesPerSecond = self.preferredFramesPerSecond;
    }

    [self setSessionPaused:NO];
}

- (void)refreshStatus {
    NSString* required = ButterscotchPathFromDataDirectory(self.launchRelativeDataWinPath);
    self.statusLabel.hidden = NO;
    self.statusLabel.text = [NSString stringWithFormat:
        @"Butterscotch iOS\n\n"
         "%@ data.win missing.\n\n"
         "Expected path:\n%@\n\n"
         "Open Files > On My iPhone/iPad > Butterscotch and copy your files.",
        self.launchTitle,
        required];
}

- (void)onRefreshTapped { [self registerUserInteraction]; [self shutdownRunnerSession]; [self attemptStartRunner]; }

- (void)onDisplayLinkTick:(CADisplayLink*)link {
    if (self.gameView == nil || self.sessionPaused) {
        return;
    }

    self.displayLinkTickCounter += 1;
    self.preferNintendoFaceSwap = BSLoadNintendoSwap();
    if (self.runnerStarted) {
        [self updateControllerInputState];
    }

    CFTimeInterval now = link.timestamp;
    if (now <= 0.0) {
        now = CACurrentMediaTime();
    }

    if (self.lastDisplayLinkTimestamp <= 0.0) {
        self.lastDisplayLinkTimestamp = now;
        self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    } else {
        CFTimeInterval elapsed = now - self.lastDisplayLinkTimestamp;
        self.lastDisplayLinkTimestamp = now;

        if (elapsed < 0.0) {
            elapsed = 0.0;
        }
        if (elapsed > 0.25) {
            elapsed = self.fixedStepDeltaSeconds;
        }

        self.accumulatedDisplaySeconds += (float) elapsed;
        if (self.accumulatedDisplaySeconds + 0.00001f < self.fixedStepDeltaSeconds) {
            return;
        }

        NSInteger speedMultiplier = 1;
        if (self.fastForwardEnabled) {
            speedMultiplier = BSLoadSpeedMultiplier();
            if (speedMultiplier < 1) speedMultiplier = 1;
            if (speedMultiplier > 4) speedMultiplier = 4;
        }
        self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
        self.pendingSimulationSteps = speedMultiplier;
        self.accumulatedDisplaySeconds -= self.fixedStepDeltaSeconds;
        if (self.accumulatedDisplaySeconds > self.fixedStepDeltaSeconds * 4.0f) {
            self.accumulatedDisplaySeconds = self.fixedStepDeltaSeconds;
        }
    }

    [self.gameView display];
}

- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
    (void) rect;

    if (!self.runnerStarted) {
        [self refreshStatus];
        return;
    }

    self.hostFrameCounter += 1;

    float dt = self.pendingFrameDeltaSeconds;
    if (dt <= 0.0f) dt = self.fixedStepDeltaSeconds;

    NSInteger steps = self.pendingSimulationSteps;
    if (steps < 1) steps = 1;
    if (steps > 4) steps = 4;

    [EAGLContext setCurrentContext:self.glContext];
    [view bindDrawable];

    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);
    ButterscotchIOS_setHostFramebuffer((uint32_t) hostFramebuffer);

    int32_t result = BS_IOS_CONTINUE;
    for (NSInteger i = 0; i < steps; i++) {
        ButterscotchIOS_beginFrame();
        result = ButterscotchIOS_stepAndDraw((int32_t) (view.drawableWidth), (int32_t) (view.drawableHeight), dt);
        if (result == BS_IOS_SHOULD_EXIT) {
            break;
        }
    }

    GLenum glErr = glGetError();
    if (glErr != GL_NO_ERROR) {
        [self appendDebugLine:[NSString stringWithFormat:@"[gl] glGetError = 0x%04x", (unsigned int) glErr]];
    }

    if (result == BS_IOS_SHOULD_EXIT) {
        [self shutdownRunnerSession];
        [self refreshStatus];
    } else if (self.videoPlayer != nil) {
        [self closeVideoPlaybackIfTimedOut];
        [self closeVideoPlaybackIfStalled];
        [self closeVideoPlaybackIfFinished];
    }
}

- (BOOL)shouldHandleTouchAsGameMouse:(UITouch*)touch {
    if (touch == nil) {
        return NO;
    }

    CGPoint location = [touch locationInView:self.view];
    UIView* hitView = [self.view hitTest:location withEvent:nil];
    if (hitView == nil) {
        return NO;
    }

    if ([hitView isDescendantOfView:self.controlsContainer] ||
        [hitView isDescendantOfView:self.menuButton] ||
        [hitView isDescendantOfView:self.fastForwardButton]) {
        return NO;
    }

    return YES;
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
    if (self.videoLayer != nil && self.gameView != nil) {
        self.videoLayer.frame = self.gameView.bounds;
    }
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

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event { (void) event; [self registerUserInteraction]; if (!self.runnerStarted) return; UITouch* touch = touches.anyObject; if (touch == nil) return; if (![self shouldHandleTouchAsGameMouse:touch]) return; [self updateMouseFromTouch:touch inView:self.view]; self.mouseDown = YES; ButterscotchIOS_setMouseButtonState(0, true); }
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event { (void) event; [self registerUserInteraction]; if (!self.runnerStarted || !self.mouseDown) return; UITouch* touch = touches.anyObject; if (touch == nil) return; [self updateMouseFromTouch:touch inView:self.view]; }
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event { (void) touches; (void) event; [self registerUserInteraction]; if (!self.runnerStarted || !self.mouseDown) return; self.mouseDown = NO; ButterscotchIOS_setMouseButtonState(0, false); }
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event { (void) touches; (void) event; [self registerUserInteraction]; if (!self.runnerStarted || !self.mouseDown) return; self.mouseDown = NO; ButterscotchIOS_setMouseButtonState(0, false); }

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; gActiveGameController = self; [self setSessionPaused:NO]; }

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self setSessionPaused:YES];
    [self closeVideoPlayback];
}

- (BOOL)videoOpenAbsolutePath:(NSString*)absolutePath {
    if (absolutePath == nil || absolutePath.length == 0) {
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
        [self appendDebugLine:[NSString stringWithFormat:@"[video] missing file: %@", absolutePath]];
        return NO;
    }

    if (self.videoEndObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.videoEndObserver];
        self.videoEndObserver = nil;
    }
    [self closeVideoPlayback];

    NSURL* url = [NSURL fileURLWithPath:absolutePath];
    AVPlayerItem* item = [AVPlayerItem playerItemWithURL:url];
    self.videoPlayer = [AVPlayer playerWithPlayerItem:item];
    atomic_store(&gIOSVideoIsOpen, true);
    self.videoPlayer.volume = self.videoVolume;
    self.videoPausedByScript = NO;
    self.videoClosePending = NO;
    self.videoLastProgressHostTime = CACurrentMediaTime();
    self.videoLastProgressSeconds = 0.0;
    self.videoOpenedHostTime = self.videoLastProgressHostTime;

    self.videoLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.videoLayer.frame = self.gameView.bounds;
    [self.gameView.layer addSublayer:self.videoLayer];

    __unsafe_unretained typeof(self) weakSelf = self;
    self.videoEndObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                    object:item
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification* notification) {
                    (void) notification;
                    if (weakSelf == nil || weakSelf.videoPlayer == nil) {
                        return;
                    }
                    if (weakSelf.videoLoopEnabled) {
                        CMTime zeroTime = (CMTime){ .value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid, .epoch = 0 };
                        [weakSelf.videoPlayer seekToTime:zeroTime toleranceBefore:zeroTime toleranceAfter:zeroTime completionHandler:^(BOOL finished) {
                            if (finished && !weakSelf.sessionPaused) {
                                [weakSelf.videoPlayer play];
                            }
                        }];
                    } else {
                        [weakSelf requestCloseVideoPlaybackWithReason:@"[video] completed (notification)"];
                    }
                }];

    CMTime observerInterval = CMTimeMakeWithSeconds(0.25, 600);
    self.videoTimeObserver = [self.videoPlayer addPeriodicTimeObserverForInterval:observerInterval
                                                                             queue:dispatch_get_main_queue()
                                                                        usingBlock:^(CMTime time) {
        (void) time;
        if (weakSelf == nil || weakSelf.videoPlayer == nil) {
            return;
        }
        // Avoid teardown reentrancy from AVPlayer callbacks.
    }];

    if (!self.sessionPaused) {
        [self.videoPlayer play];
        atomic_store(&gIOSVideoIsPlaying, true);
    } else {
        atomic_store(&gIOSVideoIsPlaying, false);
    }
    [self appendDebugLine:[NSString stringWithFormat:@"[video] playing %@", absolutePath.lastPathComponent]];
    return YES;
}

- (void)requestCloseVideoPlaybackWithReason:(NSString*)reason {
    if (self.videoPlayer == nil || self.videoClosePending) {
        return;
    }

    self.videoClosePending = YES;
    ButterscotchIOS_queueVideoCompletedEvent();
    atomic_store(&gIOSVideoIsOpen, false);
    atomic_store(&gIOSVideoIsPlaying, false);
    if (reason != nil && reason.length > 0) {
        [self appendDebugLine:reason];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.videoClosePending) {
            return;
        }
        self.videoClosePending = NO;
        [self closeVideoPlayback];
    });
}

- (void)closeVideoPlayback {
    if (self.videoPlayer != nil && self.videoTimeObserver != nil) {
        [self.videoPlayer removeTimeObserver:self.videoTimeObserver];
        self.videoTimeObserver = nil;
    }
    if (self.videoEndObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.videoEndObserver];
        self.videoEndObserver = nil;
    }
    [self.videoPlayer pause];
    [self.videoLayer removeFromSuperlayer];
    self.videoLayer = nil;
    self.videoPlayer = nil;
    self.videoPausedByScript = NO;
    self.videoClosePending = NO;
    atomic_store(&gIOSVideoIsOpen, false);
    atomic_store(&gIOSVideoIsPlaying, false);
    self.videoLastProgressHostTime = 0.0;
    self.videoLastProgressSeconds = 0.0;
    self.videoOpenedHostTime = 0.0;
}

- (void)closeVideoPlaybackIfTimedOut {
    if (self.videoPlayer == nil || self.sessionPaused || self.videoPausedByScript) {
        return;
    }
    if (self.videoOpenedHostTime <= 0.0) {
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval age = now - self.videoOpenedHostTime;
    if (age < BS_VIDEO_HARD_TIMEOUT_SECONDS) {
        return;
    }

    [self requestCloseVideoPlaybackWithReason:[NSString stringWithFormat:@"[video] completed (hard-timeout %.1fs, loop=%@)", age, self.videoLoopEnabled ? @"on" : @"off"]];
}

- (void)closeVideoPlaybackIfStalled {
    if (self.videoPlayer == nil || self.videoLoopEnabled || self.sessionPaused || self.videoPausedByScript) {
        return;
    }

    AVPlayerItem* item = self.videoPlayer.currentItem;
    if (item == nil || item.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }

    CMTime currentTime = [self.videoPlayer currentTime];
    if (currentTime.timescale <= 0 || currentTime.value < 0) {
        return;
    }

    double currentSeconds = (double) currentTime.value / (double) currentTime.timescale;
    CFTimeInterval now = CACurrentMediaTime();

    if (currentSeconds > self.videoLastProgressSeconds + 0.02) {
        self.videoLastProgressSeconds = currentSeconds;
        self.videoLastProgressHostTime = now;
        return;
    }

    if (self.videoLastProgressHostTime <= 0.0) {
        self.videoLastProgressHostTime = now;
        return;
    }

    CFTimeInterval openAge = now - self.videoLastProgressHostTime;
    if (currentSeconds <= 0.01 || openAge < BS_VIDEO_MIN_WATCHDOG_DELAY_SECONDS) {
        return;
    }

    if ((now - self.videoLastProgressHostTime) >= BS_VIDEO_STALL_TIMEOUT_SECONDS) {
        [self requestCloseVideoPlaybackWithReason:[NSString stringWithFormat:@"[video] completed (watchdog, stalled at %.2fs)", currentSeconds]];
    }
}

- (void)closeVideoPlaybackIfFinished {
    if (self.videoPlayer == nil) {
        return;
    }
    if (![self videoPlaybackHasFinished]) {
        return;
    }

    [self requestCloseVideoPlaybackWithReason:@"[video] completed (draw/poll v2)"];
}

- (BOOL)videoIsOpen {
    // Keep query methods side-effect free; teardown runs in draw/observer paths.
    return self.videoPlayer != nil;
}

- (BOOL)videoIsPlaying {
    return self.videoPlayer != nil && !self.sessionPaused && self.videoPlayer.rate > 0.0f;
}

- (BOOL)videoPlaybackHasFinished {
    if (self.videoPlayer == nil || self.videoLoopEnabled) {
        return NO;
    }

    AVPlayerItem* item = self.videoPlayer.currentItem;
    if (item == nil) {
        return NO;
    }

    if (item.status == AVPlayerItemStatusFailed || item.error != nil) {
        return YES;
    }

    CMTime duration = item.duration;
    CMTime currentTime = [self.videoPlayer currentTime];
    if (duration.timescale <= 0 || currentTime.timescale <= 0) {
        return NO;
    }
    if (duration.value <= 0 || currentTime.value < 0) {
        return NO;
    }

    double durationSeconds = (double) duration.value / (double) duration.timescale;
    double currentSeconds = (double) currentTime.value / (double) currentTime.timescale;
    double remainingSeconds = durationSeconds - currentSeconds;

    if (remainingSeconds <= 0.05) {
        return YES;
    }

    if (self.videoPlayer.rate <= 0.0f && currentSeconds > 0.0 && remainingSeconds <= 0.35) {
        return YES;
    }

    return NO;
}

- (void)videoPausePlayback { self.videoPausedByScript = YES; [self.videoPlayer pause]; atomic_store(&gIOSVideoIsPlaying, false); }
- (void)videoResumePlayback {
    self.videoPausedByScript = NO;
    if (self.videoPlayer != nil && !self.sessionPaused) {
        [self.videoPlayer play];
        atomic_store(&gIOSVideoIsPlaying, true);
    } else {
        atomic_store(&gIOSVideoIsPlaying, false);
    }
}
- (void)videoSetLoopEnabled:(BOOL)enabled { self.videoLoopEnabled = enabled; }
- (void)videoSetVolume:(float)volume { if (volume < 0.0f) volume = 0.0f; if (volume > 1.0f) volume = 1.0f; self.videoVolume = volume; if (self.videoPlayer != nil) { self.videoPlayer.volume = volume; } }
- (int32_t)videoGetFormat { return 0; }

@end

bool ButterscotchIOS_videoOpen(const char* absolutePath) {
    if (absolutePath == NULL || absolutePath[0] == '\0') {
        return false;
    }

    __block BOOL opened = NO;
    NSString* path = [NSString stringWithUTF8String:absolutePath];
    if (path == nil || path.length == 0) {
        return false;
    }

    void (^openBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            opened = [controller videoOpenAbsolutePath:path];
        }
    };

    if ([NSThread isMainThread]) {
        openBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), openBlock);
    }

    return opened;
}

void ButterscotchIOS_videoClose(void) {
    void (^closeBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            [controller closeVideoPlayback];
        } else {
            atomic_store(&gIOSVideoIsOpen, false);
            atomic_store(&gIOSVideoIsPlaying, false);
        }
    };

    if ([NSThread isMainThread]) {
        closeBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), closeBlock);
    }
}

bool ButterscotchIOS_videoIsOpen(void) {
    if ([NSThread isMainThread]) {
        ButterscotchGameViewController* controller = gActiveGameController;
        BOOL open = (controller != nil) ? [controller videoIsOpen] : NO;
        atomic_store(&gIOSVideoIsOpen, open ? true : false);
        return open ? true : false;
    } else {
        return atomic_load(&gIOSVideoIsOpen);
    }
}

bool ButterscotchIOS_videoIsPlaying(void) {
    if ([NSThread isMainThread]) {
        ButterscotchGameViewController* controller = gActiveGameController;
        BOOL playing = (controller != nil) ? [controller videoIsPlaying] : NO;
        atomic_store(&gIOSVideoIsPlaying, playing ? true : false);
        return playing ? true : false;
    } else {
        return atomic_load(&gIOSVideoIsPlaying);
    }
}

void ButterscotchIOS_videoPause(void) {
    void (^pauseBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            [controller videoPausePlayback];
        } else {
            atomic_store(&gIOSVideoIsPlaying, false);
        }
    };

    if ([NSThread isMainThread]) {
        pauseBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), pauseBlock);
    }
}

void ButterscotchIOS_videoResume(void) {
    void (^resumeBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            [controller videoResumePlayback];
        } else {
            atomic_store(&gIOSVideoIsPlaying, false);
        }
    };

    if ([NSThread isMainThread]) {
        resumeBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), resumeBlock);
    }
}

void ButterscotchIOS_videoEnableLoop(bool enabled) {
    void (^loopBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            [controller videoSetLoopEnabled:enabled ? YES : NO];
        }
    };

    if ([NSThread isMainThread]) {
        loopBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), loopBlock);
    }
}

void ButterscotchIOS_videoSetVolume(float volume) {
    void (^volumeBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            [controller videoSetVolume:volume];
        }
    };

    if ([NSThread isMainThread]) {
        volumeBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), volumeBlock);
    }
}

int32_t ButterscotchIOS_videoGetFormat(void) {
    __block int32_t format = 0;
    void (^formatBlock)(void) = ^{
        ButterscotchGameViewController* controller = gActiveGameController;
        if (controller != nil) {
            format = [controller videoGetFormat];
        }
    };

    if ([NSThread isMainThread]) {
        formatBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), formatBlock);
    }

    return format;
}
