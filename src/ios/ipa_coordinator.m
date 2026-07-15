#import "ipa_coordinator.h"

#include "ios/butterscotch_ios.h"
#include "ios/ipa_support.h"

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

@interface ButterscotchLibraryViewController ()
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

- (void)onReturnToGame { [self.coordinator resumeActiveGame]; }

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section { (void) tableView; (void) section; return BSLaunchCatalog().count; }

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

@interface ButterscotchSettingsViewController ()
- (void)onSpeedChanged:(UISegmentedControl*)sender;
- (void)onSwapChanged:(UISwitch*)sender;
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

- (void)onSpeedChanged:(UISegmentedControl*)sender { BSSaveSpeedMultiplier(sender.selectedSegmentIndex + 1); }
- (void)onSwapChanged:(UISwitch*)sender { BSSaveNintendoSwap(sender.on); }

@end

@interface ButterscotchAppCoordinator ()
- (void)startLaunchInfo:(NSDictionary<NSString*, NSString*>*)launchInfo;
- (void)showLoadingOverlayWithTitle:(NSString*)title;
- (void)hideLoadingOverlay;
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

- (void)showLoadingOverlayWithTitle:(NSString*)title {
    [self hideLoadingOverlay];

    UIView* overlay = [[UIView alloc] initWithFrame:self.rootTabBarController.view.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.92];

    UIActivityIndicatorView* spinner;
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    } else {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];

    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];

    [overlay addSubview:spinner];
    [overlay addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor constant:-18.0],
        [label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:18.0],
        [label.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
    ]];

    [self.rootTabBarController.view addSubview:overlay];
    self.loadingOverlayView = overlay;
}

- (void)hideLoadingOverlay { [self.loadingOverlayView removeFromSuperview]; self.loadingOverlayView = nil; }
- (BOOL)hasActiveGame { return self.activeGameController != nil; }

- (void)resumeActiveGame {
    if (self.activeGameController == nil) {
        return;
    }
    if (self.rootTabBarController.presentedViewController == self.activeGameController) {
        return;
    }
    [self.rootTabBarController presentViewController:self.activeGameController animated:YES completion:^{
        [self.activeGameController setSessionPaused:NO];
    }];
}

- (void)startLaunchInfo:(NSDictionary<NSString*, NSString*>*)launchInfo {
    [self showLoadingOverlayWithTitle:[NSString stringWithFormat:@"Loading %@…", launchInfo[@"title"]]];

    ButterscotchGameViewController* controller = [[ButterscotchGameViewController alloc] initWithLaunchInfo:launchInfo];
    controller.delegate = self;
    self.activeGameController = controller;
    self.activeLaunchInfo = launchInfo;

    [self.rootTabBarController presentViewController:controller animated:YES completion:^{
        [self hideLoadingOverlay];
    }];
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
    [controller setSessionPaused:YES];
    ButterscotchIOS_videoClose();
    if (self.rootTabBarController.presentedViewController == controller) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
