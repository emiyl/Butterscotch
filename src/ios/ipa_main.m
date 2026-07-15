#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <QuartzCore/CADisplayLink.h>
#import <GameController/GameController.h>
#import <OpenGLES/ES3/gl.h>

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

static const int32_t BS_KEY_DIR_LEFT_ALT = 'A';
static const int32_t BS_KEY_DIR_RIGHT_ALT = 'D';
static const int32_t BS_KEY_DIR_UP_ALT = 'W';
static const int32_t BS_KEY_DIR_DOWN_ALT = 'S';

static NSString* const BS_SETTING_SPEED_MULTIPLIER = @"bs.settings.speedMultiplier";
static NSString* const BS_SETTING_NINTENDO_SWAP = @"bs.settings.nintendoSwap";

static NSInteger BSLoadSpeedMultiplier(void) {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:BS_SETTING_SPEED_MULTIPLIER];
    if (value < 1 || value > 4) {
        return 1;
    }
    return value;
}

static void BSSaveSpeedMultiplier(NSInteger value) {
    NSInteger clamped = value;
    if (clamped < 1) clamped = 1;
    if (clamped > 4) clamped = 4;
    [[NSUserDefaults standardUserDefaults] setInteger:clamped forKey:BS_SETTING_SPEED_MULTIPLIER];
}

static BOOL BSLoadNintendoSwap(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:BS_SETTING_NINTENDO_SWAP];
}

static void BSSaveNintendoSwap(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:BS_SETTING_NINTENDO_SWAP];
}

static NSArray<NSDictionary<NSString*, NSString*>*>* BSLaunchCatalog(void) {
    static NSArray<NSDictionary<NSString*, NSString*>*>* catalog = nil;
    if (catalog == nil) {
        catalog = @[
            @{ @"key": @"undertale", @"title": @"Undertale", @"relative": @"Undertale/data.win" },
            @{ @"key": @"dr_ch1", @"title": @"DELTARUNE Chapter 1", @"relative": @"DELTARUNE/chapter1_windows/data.win" },
            @{ @"key": @"dr_ch2", @"title": @"DELTARUNE Chapter 2", @"relative": @"DELTARUNE/chapter2_windows/data.win" },
            @{ @"key": @"dr_ch3", @"title": @"DELTARUNE Chapter 3", @"relative": @"DELTARUNE/chapter3_windows/data.win" },
            @{ @"key": @"dr_ch4", @"title": @"DELTARUNE Chapter 4", @"relative": @"DELTARUNE/chapter4_windows/data.win" },
            @{ @"key": @"dr_ch5", @"title": @"DELTARUNE Chapter 5", @"relative": @"DELTARUNE/chapter5_windows/data.win" },
        ];
    }
    return catalog;
}

@class ButterscotchGameViewController;

@protocol ButterscotchGameViewControllerDelegate <NSObject>
- (void)gameViewControllerDidRequestReturnToLibrary:(ButterscotchGameViewController*)controller;
@end

@interface ButterscotchGameViewController : GLKViewController
@property(strong, nonatomic) NSString* launchKey;
@property(strong, nonatomic) NSString* launchTitle;
@property(strong, nonatomic) NSString* launchRelativeDataWinPath;
@property(assign, nonatomic) id<ButterscotchGameViewControllerDelegate> delegate;

@property(strong, nonatomic) UILabel* statusLabel;
@property(strong, nonatomic) UIButton* menuButton;
@property(strong, nonatomic) UITextView* debugTextView;
@property(strong, nonatomic) UIView* controlsContainer;
@property(strong, nonatomic) GLKView* gameView;
@property(strong, nonatomic) EAGLContext* glContext;
@property(strong, nonatomic) CADisplayLink* displayLink;
@property(strong, nonatomic) NSMutableArray<NSString*>* debugLines;
@property(assign, nonatomic) BOOL runnerStarted;
@property(assign, nonatomic) BOOL mouseDown;
@property(assign, nonatomic) BOOL logVisible;
@property(assign, nonatomic) BOOL controlsVisible;
@property(assign, nonatomic) BOOL sawNoPresentResult;
@property(assign, nonatomic) BOOL sawFirstDrawCallback;
@property(assign, nonatomic) uint64_t hostFrameCounter;
@property(assign, nonatomic) uint64_t displayLinkTickCounter;
@property(assign, nonatomic) unsigned long long runtimeLogOffset;
@property(assign, nonatomic) float fixedStepDeltaSeconds;
@property(assign, nonatomic) float accumulatedDisplaySeconds;
@property(assign, nonatomic) float pendingFrameDeltaSeconds;
@property(assign, nonatomic) CFTimeInterval lastDisplayLinkTimestamp;
@property(assign, nonatomic) BOOL preferNintendoFaceSwap;
@property(strong, nonatomic) NSTimer* menuAutoHideTimer;
@property(strong, nonatomic) NSLayoutConstraint* gameViewLeadingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTrailingConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewTopConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewBottomConstraint;
@property(strong, nonatomic) NSLayoutConstraint* gameViewPortraitHeightConstraint;

- (instancetype)initWithLaunchInfo:(NSDictionary<NSString*, NSString*>*)launchInfo;
- (void)shutdownRunnerSession;
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
- (void)registerUserInteraction;
- (void)resetMenuAutoHideTimer;
- (void)onMenuAutoHideTimerFired:(NSTimer*)timer;
- (BOOL)shouldHandleTouchAsGameMouse:(UITouch*)touch;
- (void)pollRuntimeLog;
- (void)attemptStartRunner;
- (void)refreshStatus;
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
    self.runtimeLogOffset = 0;
    self.fixedStepDeltaSeconds = 1.0f / 60.0f;
    self.accumulatedDisplaySeconds = 0.0f;
    self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    self.lastDisplayLinkTimestamp = 0.0;
    self.logVisible = NO;
    self.controlsVisible = YES;
    self.preferNintendoFaceSwap = BSLoadNintendoSwap();
    self.debugLines = [NSMutableArray array];

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
    [self rebuildOptionsMenu];
    [self registerUserInteraction];

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
    ]];

    [self setupVirtualControls];

    [self appendDebugLine:[NSString stringWithFormat:@"[host] launch: %@", self.launchTitle]];
    [self appendDebugLine:[NSString stringWithFormat:@"[host] data folder: %@", ButterscotchDataDirectory()]];
    [self appendDebugLine:[NSString stringWithFormat:@"[host] runtime log: %@", ButterscotchRuntimeLogPath()]];
    [self attemptStartRunner];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.displayLink invalidate];
    self.displayLink = nil;

    [self.menuAutoHideTimer invalidate];
    self.menuAutoHideTimer = nil;

    [self shutdownRunnerSession];

    if ([EAGLContext currentContext] == self.glContext) {
        [EAGLContext setCurrentContext:nil];
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)shutdownRunnerSession {
    if (!self.runnerStarted) {
        return;
    }

    ButterscotchIOS_stopRunner();
    self.runnerStarted = NO;
    self.accumulatedDisplaySeconds = 0.0f;
    self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds;
    self.lastDisplayLinkTimestamp = 0.0;
    for (int32_t i = 0; i < GML_KEY_COUNT; i++) {
        _keySourceMask[i] = 0;
    }
}

- (void)appendDebugLine:(NSString*)line {
    if (line == nil || line.length == 0) {
        return;
    }

    [self.debugLines addObject:line];
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

- (void)setDirectionalKeysForArrow:(int32_t)arrow source:(uint8_t)source down:(BOOL)down {
    if (arrow == VK_LEFT) {
        [self setVirtualKey:VK_LEFT source:source down:down];
        [self setVirtualKey:BS_KEY_DIR_LEFT_ALT source:source down:down];
    } else if (arrow == VK_RIGHT) {
        [self setVirtualKey:VK_RIGHT source:source down:down];
        [self setVirtualKey:BS_KEY_DIR_RIGHT_ALT source:source down:down];
    } else if (arrow == VK_UP) {
        [self setVirtualKey:VK_UP source:source down:down];
        [self setVirtualKey:BS_KEY_DIR_UP_ALT source:source down:down];
    } else if (arrow == VK_DOWN) {
        [self setVirtualKey:VK_DOWN source:source down:down];
        [self setVirtualKey:BS_KEY_DIR_DOWN_ALT source:source down:down];
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

        // UIAction* refreshAction = [UIAction actionWithTitle:@"Refresh" image:nil identifier:nil handler:^(__kindof UIAction* action) {
        //     (void) action;
        //     [weakSelf registerUserInteraction];
        //     [weakSelf onRefreshTapped];
        // }];

        NSString* logTitle = self.logVisible ? @"Hide Log" : @"Show log";
        UIAction* logAction = [UIAction actionWithTitle:logTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            [weakSelf registerUserInteraction];
            weakSelf.logVisible = !weakSelf.logVisible;
            weakSelf.debugTextView.hidden = !weakSelf.logVisible;
            [weakSelf rebuildOptionsMenu];
        }];

        NSString* controlsTitle = self.controlsVisible ? @"Hide on-screen controller" : @"Show on-screen controller";
        UIAction* controlsAction = [UIAction actionWithTitle:controlsTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
            (void) action;
            [weakSelf registerUserInteraction];
            weakSelf.controlsVisible = !weakSelf.controlsVisible;
            weakSelf.controlsContainer.hidden = !weakSelf.controlsVisible;
            [weakSelf rebuildOptionsMenu];
        }];

        // NSString* swapTitle = self.preferNintendoFaceSwap ? @"Nintendo A/B + X/Y: On" : @"Nintendo A/B + X/Y: Off";
        // UIAction* swapAction = [UIAction actionWithTitle:swapTitle image:nil identifier:nil handler:^(__kindof UIAction* action) {
        //     (void) action;
        //     [weakSelf registerUserInteraction];
        //     weakSelf.preferNintendoFaceSwap = !weakSelf.preferNintendoFaceSwap;
        //     BSSaveNintendoSwap(weakSelf.preferNintendoFaceSwap);
        //     [weakSelf rebuildOptionsMenu];
        // }];

        self.menuButton.menu = [UIMenu menuWithTitle:@"" children:@[
            backAction,
            // refreshAction,
            logAction, controlsAction,
            // swapAction
        ]];
        self.menuButton.showsMenuAsPrimaryAction = YES;
    }
}

- (void)registerUserInteraction {
    self.menuButton.hidden = NO;
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
}

- (void)onControllerConnected:(NSNotification*)notification {
    (void) notification;
    [self registerUserInteraction];
    [self appendDebugLine:@"[host] bluetooth controller connected"];
}

- (void)onControllerDisconnected:(NSNotification*)notification {
    (void) notification;
    [self registerUserInteraction];
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
    for (NSString* line in lines) {
        NSString* trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            continue;
        }
        if (!ShouldDisplayRuntimeLogLine(trimmed)) {
            continue;
        }
        [self appendDebugLine:[NSString stringWithFormat:@"[stderr] %@", trimmed]];
    }
}

- (void)attemptStartRunner {
    EnsureDataDirectoryAndHintFile();
    RedirectStderrToRuntimeLog();
    [self pollRuntimeLog];

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

    NSString* savesPath = ButterscotchPathFromDataDirectory([NSString stringWithFormat:@"saves/%@", self.launchKey]);
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:savesPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        [self appendDebugLine:[NSString stringWithFormat:@"[host] failed to create saves dir: %@", error.localizedDescription]];
    }

    [self.gameView bindDrawable];
    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);

    BOOL started = ButterscotchIOS_startRunner(dataWinPath.UTF8String, savesPath.UTF8String, BS_IOS_OS_IOS, (uint32_t) hostFramebuffer);
    [self pollRuntimeLog];
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
}

- (void)refreshStatus {
    NSString* required = ButterscotchPathFromDataDirectory(self.launchRelativeDataWinPath);
    self.statusLabel.hidden = NO;
    self.statusLabel.text = [NSString stringWithFormat:
        @"Butterscotch iOS\n\n"
         "%@ data.win missing.\n\n"
         "Expected path:\n%@\n\n"
         "Open Files > On My iPhone/iPad > Butterscotch and copy your files, then tap Refresh.",
        self.launchTitle,
        required];
}

- (void)onRefreshTapped {
    [self registerUserInteraction];
    [self pollRuntimeLog];

    [self shutdownRunnerSession];
    [self attemptStartRunner];
}

- (void)onDisplayLinkTick:(CADisplayLink*)link {
    if (self.gameView == nil) {
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

        NSInteger speedMultiplier = BSLoadSpeedMultiplier();
        self.pendingFrameDeltaSeconds = self.fixedStepDeltaSeconds * (float) speedMultiplier;
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
        [self pollRuntimeLog];
        [self refreshStatus];
        return;
    }

    self.hostFrameCounter += 1;

    float dt = self.pendingFrameDeltaSeconds;
    if (dt <= 0.0f) {
        dt = self.fixedStepDeltaSeconds;
    }

    [EAGLContext setCurrentContext:self.glContext];
    [view bindDrawable];

    GLint hostFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &hostFramebuffer);
    ButterscotchIOS_setHostFramebuffer((uint32_t) hostFramebuffer);

    ButterscotchIOS_beginFrame();
    int32_t result = ButterscotchIOS_stepAndDraw((int32_t) (view.drawableWidth), (int32_t) (view.drawableHeight), dt);
    [self pollRuntimeLog];

    GLenum glErr = glGetError();
    if (glErr != GL_NO_ERROR) {
        [self appendDebugLine:[NSString stringWithFormat:@"[gl] glGetError = 0x%04x", (unsigned int) glErr]];
    }

    if (result == BS_IOS_SHOULD_EXIT) {
        [self shutdownRunnerSession];
        [self refreshStatus];
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
        [hitView isDescendantOfView:self.debugTextView]) {
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
    [self registerUserInteraction];
    if (!self.runnerStarted) return;
    UITouch* touch = touches.anyObject;
    if (touch == nil) return;
    if (![self shouldHandleTouchAsGameMouse:touch]) return;
    [self updateMouseFromTouch:touch inView:self.view];
    self.mouseDown = YES;
    ButterscotchIOS_setMouseButtonState(0, true);
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) event;
    [self registerUserInteraction];
    if (!self.runnerStarted || !self.mouseDown) return;
    UITouch* touch = touches.anyObject;
    if (touch == nil) return;
    [self updateMouseFromTouch:touch inView:self.view];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) touches;
    (void) event;
    [self registerUserInteraction];
    if (!self.runnerStarted || !self.mouseDown) return;
    self.mouseDown = NO;
    ButterscotchIOS_setMouseButtonState(0, false);
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    (void) touches;
    (void) event;
    [self registerUserInteraction];
    if (!self.runnerStarted || !self.mouseDown) return;
    self.mouseDown = NO;
    ButterscotchIOS_setMouseButtonState(0, false);
}

@end

@class ButterscotchAppCoordinator;

@interface ButterscotchLibraryViewController : UITableViewController
@property(assign, nonatomic) ButterscotchAppCoordinator* coordinator;
@end

@interface ButterscotchSettingsViewController : UIViewController
@property(strong, nonatomic) UISegmentedControl* speedControl;
@property(strong, nonatomic) UISwitch* nintendoSwapSwitch;
@end

@interface ButterscotchAppCoordinator : NSObject <ButterscotchGameViewControllerDelegate>
@property(strong, nonatomic) UITabBarController* rootTabBarController;
@property(strong, nonatomic) ButterscotchLibraryViewController* libraryController;
@property(strong, nonatomic) ButterscotchSettingsViewController* settingsController;
@property(strong, nonatomic) ButterscotchGameViewController* activeGameController;
@property(strong, nonatomic) NSDictionary<NSString*, NSString*>* activeLaunchInfo;
- (UIViewController*)buildRootController;
- (BOOL)hasActiveGame;
- (void)resumeActiveGame;
- (void)handleLaunchSelection:(NSDictionary<NSString*, NSString*>*)launchInfo fromPresenter:(UIViewController*)presenter;
@end

@implementation ButterscotchLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Games";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LaunchCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self.coordinator hasActiveGame]) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Return To Game" style:UIBarButtonItemStylePlain target:self action:@selector(onReturnToGame)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)onReturnToGame {
    [self.coordinator resumeActiveGame];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void) tableView;
    (void) section;
    return BSLaunchCatalog().count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"LaunchCell" forIndexPath:indexPath];
    NSDictionary<NSString*, NSString*>* launchInfo = BSLaunchCatalog()[(NSUInteger) indexPath.row];
    cell.textLabel.text = launchInfo[@"title"];
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString*, NSString*>* launchInfo = BSLaunchCatalog()[(NSUInteger) indexPath.row];
    [self.coordinator handleLaunchSelection:launchInfo fromPresenter:self];
}

@end

@implementation ButterscotchSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Settings";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel* speedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    speedLabel.text = @"Speed Multiplier";
    speedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

    self.speedControl = [[UISegmentedControl alloc] initWithItems:@[@"1x", @"2x", @"3x", @"4x"]];
    self.speedControl.translatesAutoresizingMaskIntoConstraints = NO;
    NSInteger speedMultiplier = BSLoadSpeedMultiplier();
    self.speedControl.selectedSegmentIndex = speedMultiplier - 1;
    [self.speedControl addTarget:self action:@selector(onSpeedChanged:) forControlEvents:UIControlEventValueChanged];

    UILabel* swapLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    swapLabel.translatesAutoresizingMaskIntoConstraints = NO;
    swapLabel.text = @"Nintendo A/B + X/Y Swap";
    swapLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

    self.nintendoSwapSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.nintendoSwapSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.nintendoSwapSwitch.on = BSLoadNintendoSwap();
    [self.nintendoSwapSwitch addTarget:self action:@selector(onSwapChanged:) forControlEvents:UIControlEventValueChanged];

    UILabel* noteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    noteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    noteLabel.numberOfLines = 0;
    noteLabel.textColor = [UIColor secondaryLabelColor];
    noteLabel.text = @"Settings are saved on-device and applied to future game sessions.";

    [self.view addSubview:speedLabel];
    [self.view addSubview:self.speedControl];
    [self.view addSubview:swapLabel];
    [self.view addSubview:self.nintendoSwapSwitch];
    [self.view addSubview:noteLabel];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [speedLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [speedLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:24.0],

        [self.speedControl.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [self.speedControl.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [self.speedControl.topAnchor constraintEqualToAnchor:speedLabel.bottomAnchor constant:12.0],

        [swapLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [swapLabel.topAnchor constraintEqualToAnchor:self.speedControl.bottomAnchor constant:28.0],

        [self.nintendoSwapSwitch.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [self.nintendoSwapSwitch.centerYAnchor constraintEqualToAnchor:swapLabel.centerYAnchor],

        [noteLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [noteLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [noteLabel.topAnchor constraintEqualToAnchor:swapLabel.bottomAnchor constant:20.0],
    ]];
}

- (void)onSpeedChanged:(UISegmentedControl*)sender {
    NSInteger multiplier = sender.selectedSegmentIndex + 1;
    BSSaveSpeedMultiplier(multiplier);
}

- (void)onSwapChanged:(UISwitch*)sender {
    BSSaveNintendoSwap(sender.on);
}

@end

@implementation ButterscotchAppCoordinator

- (UIViewController*)buildRootController {
    self.libraryController = [ButterscotchLibraryViewController new];
    self.libraryController.coordinator = self;

    self.settingsController = [ButterscotchSettingsViewController new];

    UINavigationController* libraryNav = [[UINavigationController alloc] initWithRootViewController:self.libraryController];
    UINavigationController* settingsNav = [[UINavigationController alloc] initWithRootViewController:self.settingsController];

    libraryNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Library" image:[UIImage systemImageNamed:@"list.bullet.rectangle"] tag:0];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:[UIImage systemImageNamed:@"gearshape"] tag:1];

    self.rootTabBarController = [UITabBarController new];
    self.rootTabBarController.viewControllers = @[libraryNav, settingsNav];

    return self.rootTabBarController;
}

- (BOOL)hasActiveGame {
    return self.activeGameController != nil;
}

- (void)resumeActiveGame {
    if (self.activeGameController == nil) {
        return;
    }
    if (self.rootTabBarController.presentedViewController == self.activeGameController) {
        return;
    }
    [self.rootTabBarController presentViewController:self.activeGameController animated:YES completion:nil];
}

- (void)startLaunchInfo:(NSDictionary<NSString*, NSString*>*)launchInfo {
    ButterscotchGameViewController* controller = [[ButterscotchGameViewController alloc] initWithLaunchInfo:launchInfo];
    controller.delegate = self;
    self.activeGameController = controller;
    self.activeLaunchInfo = launchInfo;

    [self.rootTabBarController presentViewController:controller animated:YES completion:nil];
}

- (void)handleLaunchSelection:(NSDictionary<NSString*, NSString*>*)launchInfo fromPresenter:(UIViewController*)presenter {
    if (self.activeGameController == nil) {
        [self startLaunchInfo:launchInfo];
        return;
    }

    NSString* selectedKey = launchInfo[@"key"];
    NSString* activeKey = self.activeLaunchInfo[@"key"];
    if (selectedKey != nil && [selectedKey isEqualToString:activeKey]) {
        [self resumeActiveGame];
        return;
    }

    __unsafe_unretained typeof(self) weakSelf = self;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Launch New Chapter?"
                                                                   message:@"Unsaved progress in the current session will be lost."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Launch" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
        (void) action;
        [weakSelf.activeGameController shutdownRunnerSession];
        if (weakSelf.rootTabBarController.presentedViewController == weakSelf.activeGameController) {
            [weakSelf.activeGameController dismissViewControllerAnimated:NO completion:nil];
        }
        weakSelf.activeGameController = nil;
        weakSelf.activeLaunchInfo = nil;
        [weakSelf startLaunchInfo:launchInfo];
    }]];

    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)gameViewControllerDidRequestReturnToLibrary:(ButterscotchGameViewController*)controller {
    if (self.rootTabBarController.presentedViewController == controller) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

@end

@interface ButterscotchAppDelegate : UIResponder <UIApplicationDelegate>
@property(strong, nonatomic) UIWindow* window;
@property(strong, nonatomic) ButterscotchAppCoordinator* coordinator;
@end

@implementation ButterscotchAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void) application;
    (void) launchOptions;

    EnsureDataDirectoryAndHintFile();

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.coordinator = [ButterscotchAppCoordinator new];
    self.window.rootViewController = [self.coordinator buildRootController];
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
