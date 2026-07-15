#ifndef BUTTERSCOTCH_IOS_IPA_SUPPORT_H
#define BUTTERSCOTCH_IOS_IPA_SUPPORT_H

#import <UIKit/UIKit.h>

@interface ButterscotchPassthroughView : UIView
@end

NSString *ButterscotchDataDirectory(void);
NSString *ButterscotchDataWinPath(void);
NSString *ButterscotchInstructionsPath(void);
NSString *ButterscotchRuntimeLogPath(void);

BOOL ShouldDisplayRuntimeLogLine(NSString *line);
void RedirectStderrToRuntimeLog(void);
void EnsureDataDirectoryAndHintFile(void);

#endif
