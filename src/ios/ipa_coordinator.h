#ifndef BUTTERSCOTCH_IOS_IPA_COORDINATOR_H
#define BUTTERSCOTCH_IOS_IPA_COORDINATOR_H

#import <UIKit/UIKit.h>

#import "ipa_game_view_controller.h"
#import "ipa_settings.h"

@class ButterscotchLibraryViewController;
@class ButterscotchSettingsViewController;

@interface ButterscotchAppCoordinator
    : NSObject <ButterscotchGameViewControllerDelegate>
@property(strong, nonatomic) UITabBarController *rootTabBarController;
@property(strong, nonatomic)
    ButterscotchLibraryViewController *libraryController;
@property(strong, nonatomic)
    ButterscotchSettingsViewController *settingsController;
@property(strong, nonatomic)
    ButterscotchGameViewController *activeGameController;
@property(strong, nonatomic)
    NSDictionary<NSString *, NSString *> *activeLaunchInfo;
@property(strong, nonatomic) UIView *loadingOverlayView;
- (UIViewController *)buildRootController;
- (BOOL)hasActiveGame;
- (void)resumeActiveGame;
- (void)handleLaunchSelection:(NSDictionary<NSString *, NSString *> *)launchInfo
                fromPresenter:(UIViewController *)presenter;
@end

@interface ButterscotchLibraryViewController : UITableViewController
@property(assign, nonatomic) ButterscotchAppCoordinator *coordinator;
@end

@interface ButterscotchSettingsViewController : UIViewController
@property(strong, nonatomic) UISegmentedControl *speedControl;
@property(strong, nonatomic) UISwitch *nintendoSwapSwitch;
@end

#endif