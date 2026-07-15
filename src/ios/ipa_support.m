#import "ios/ipa_support.h"

#include <fcntl.h>
#include <unistd.h>

@implementation ButterscotchPassthroughView
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

NSString* ButterscotchDataDirectory(void) {
    NSString* documentsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsDir stringByAppendingPathComponent:@"Butterscotch"];
}

NSString* ButterscotchDataWinPath(void) {
    return [[ButterscotchDataDirectory() stringByAppendingPathComponent:@"active_chapter"] stringByAppendingPathComponent:@"data.win"];
}

NSString* ButterscotchInstructionsPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"PLACE_DATA_WIN_HERE.txt"];
}

NSString* ButterscotchRuntimeLogPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"runtime.log"];
}

BOOL ShouldDisplayRuntimeLogLine(NSString* line) {
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

void RedirectStderrToRuntimeLog(void) {
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

void EnsureDataDirectoryAndHintFile(void) {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* dirPath = ButterscotchDataDirectory();
    NSString* chapterDirPath = [dirPath stringByAppendingPathComponent:@"active_chapter"];
    NSError* error = nil;

    if (![fileManager fileExistsAtPath:dirPath]) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Could not create data directory %@: %@", dirPath, error);
            error = nil;
        }
    }

    if (![fileManager fileExistsAtPath:chapterDirPath]) {
        [fileManager createDirectoryAtPath:chapterDirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Could not create active chapter directory %@: %@", chapterDirPath, error);
            error = nil;
        }
    }

    NSString* hintPath = ButterscotchInstructionsPath();
    if (![fileManager fileExistsAtPath:hintPath]) {
        NSString* hint = @"Place your GameMaker data.win file in active_chapter/data.win and relaunch Butterscotch.\nExpected filename: active_chapter/data.win\n";
        [hint writeToFile:hintPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error != nil) {
            NSLog(@"Could not write hint file %@: %@", hintPath, error);
        }
    }
}
