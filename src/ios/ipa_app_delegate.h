#ifndef BUTTERSCOTCH_IOS_IPA_APP_DELEGATE_H
#define BUTTERSCOTCH_IOS_IPA_APP_DELEGATE_H

#import <UIKit/UIKit.h>

#import "ipa_coordinator.h"

@interface ButterscotchAppDelegate : UIResponder <UIApplicationDelegate>
@property(strong, nonatomic) UIWindow *window;
@property(strong, nonatomic) ButterscotchAppCoordinator *coordinator;
@end

#endif