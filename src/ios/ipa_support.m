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
    return ButterscotchPathFromDataDirectory(@"Undertale/data.win");
}

NSString* ButterscotchPathFromDataDirectory(NSString* relativePath) {
    if (relativePath == nil || relativePath.length == 0) {
        return ButterscotchDataDirectory();
    }
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:relativePath];
}

NSString* ButterscotchInstructionsPath(void) {
    return [ButterscotchDataDirectory() stringByAppendingPathComponent:@"PLACE_GAMES_HERE.txt"];
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
    NSArray<NSString*>* requiredDirectories = @[
        @"Undertale",
        @"DELTARUNE",
        @"DELTARUNE/mus",
        @"DELTARUNE/chapter1_windows",
        @"DELTARUNE/chapter2_windows",
        @"DELTARUNE/chapter3_windows",
        @"DELTARUNE/chapter4_windows",
        @"DELTARUNE/chapter5_windows",
    ];
    NSError* error = nil;

    if (![fileManager fileExistsAtPath:dirPath]) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Could not create data directory %@: %@", dirPath, error);
            error = nil;
        }
    }

    for (NSString* relativeDir in requiredDirectories) {
        NSString* fullPath = ButterscotchPathFromDataDirectory(relativeDir);
        if ([fileManager fileExistsAtPath:fullPath]) {
            continue;
        }
        [fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            NSLog(@"Could not create directory %@: %@", fullPath, error);
            error = nil;
        }
    }

    // DELTARUNE chapters may request mus from chapterX_windows/mus. Link that to DELTARUNE/mus.
    NSArray<NSString*>* chapterDirs = @[
        @"DELTARUNE/chapter1_windows",
        @"DELTARUNE/chapter2_windows",
        @"DELTARUNE/chapter3_windows",
        @"DELTARUNE/chapter4_windows",
        @"DELTARUNE/chapter5_windows",
    ];
    for (NSString* chapterDir in chapterDirs) {
        NSString* chapterMusPath = ButterscotchPathFromDataDirectory([chapterDir stringByAppendingPathComponent:@"mus"]);
        if ([fileManager fileExistsAtPath:chapterMusPath]) {
            continue;
        }
        [fileManager createSymbolicLinkAtPath:chapterMusPath withDestinationPath:@"../mus" error:&error];
        if (error != nil) {
            // If symlink creation fails, keep going; user can still place chapter-local mus.
            NSLog(@"Could not create mus symlink %@: %@", chapterMusPath, error);
            error = nil;
        }
    }

    NSString* hintPath = ButterscotchInstructionsPath();
    NSString* hint =
        @"Place your game files using this layout:\n"
         "- Undertale/data.win\n"
         "- DELTARUNE/chapter1_windows/data.win\n"
         "- DELTARUNE/chapter2_windows/data.win\n"
         "- DELTARUNE/chapter3_windows/data.win\n"
         "- DELTARUNE/chapter4_windows/data.win\n"
         "- DELTARUNE/chapter5_windows/data.win\n"
         "- DELTARUNE/mus\n";
    [hint writeToFile:hintPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error != nil) {
        NSLog(@"Could not write hint file %@: %@", hintPath, error);
    }
}
