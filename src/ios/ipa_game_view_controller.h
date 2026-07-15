#ifndef BUTTERSCOTCH_IOS_IPA_GAME_VIEW_CONTROLLER_H
#define BUTTERSCOTCH_IOS_IPA_GAME_VIEW_CONTROLLER_H

#import <GLKit/GLKit.h>

@class ButterscotchGameViewController;

@protocol ButterscotchGameViewControllerDelegate <NSObject>
- (void)gameViewControllerDidRequestReturnToLibrary:
    (ButterscotchGameViewController *)controller;
@end

@interface ButterscotchGameViewController : GLKViewController
@property(strong, nonatomic) NSString *launchKey;
@property(strong, nonatomic) NSString *launchTitle;
@property(strong, nonatomic) NSString *launchRelativeDataWinPath;
@property(assign, nonatomic) id<ButterscotchGameViewControllerDelegate>
    delegate;

- (instancetype)initWithLaunchInfo:
    (NSDictionary<NSString *, NSString *> *)launchInfo;
- (void)shutdownRunnerSession;
- (void)setSessionPaused:(BOOL)paused;
@end

#endif