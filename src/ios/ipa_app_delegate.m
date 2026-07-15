#import "ipa_app_delegate.h"

#include "ios/ipa_support.h"
#include "ios/butterscotch_ios.h"

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

- (void)applicationWillResignActive:(UIApplication*)application { (void) application; ButterscotchIOS_suspendAudio(); }
- (void)applicationDidEnterBackground:(UIApplication*)application { (void) application; ButterscotchIOS_suspendAudio(); }
- (void)applicationWillEnterForeground:(UIApplication*)application { (void) application; ButterscotchIOS_resumeAudio(); }
- (void)applicationDidBecomeActive:(UIApplication*)application { (void) application; ButterscotchIOS_resumeAudio(); }

@end
