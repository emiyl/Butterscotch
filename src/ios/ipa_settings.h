#ifndef BUTTERSCOTCH_IOS_IPA_SETTINGS_H
#define BUTTERSCOTCH_IOS_IPA_SETTINGS_H

#import <Foundation/Foundation.h>

static NSString* const BS_SETTING_SPEED_MULTIPLIER = @"bs.settings.speedMultiplier";
static NSString* const BS_SETTING_NINTENDO_SWAP = @"bs.settings.nintendoSwap";

static inline NSInteger BSLoadSpeedMultiplier(void) {
	NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:BS_SETTING_SPEED_MULTIPLIER];
	if (value < 1 || value > 4) {
		return 1;
	}
	return value;
}

static inline void BSSaveSpeedMultiplier(NSInteger value) {
	NSInteger clamped = value;
	if (clamped < 1) clamped = 1;
	if (clamped > 4) clamped = 4;
	[[NSUserDefaults standardUserDefaults] setInteger:clamped forKey:BS_SETTING_SPEED_MULTIPLIER];
}

static inline BOOL BSLoadNintendoSwap(void) {
	return [[NSUserDefaults standardUserDefaults] boolForKey:BS_SETTING_NINTENDO_SWAP];
}

static inline void BSSaveNintendoSwap(BOOL enabled) {
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:BS_SETTING_NINTENDO_SWAP];
}

#endif