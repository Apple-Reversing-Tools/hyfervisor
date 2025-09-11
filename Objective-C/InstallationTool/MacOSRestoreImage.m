/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Download the latest macOS restore image from the network.
*/

#import "MacOSRestoreImage.h"

#import "Error.h"
#import "Path.h"

#import <Virtualization/Virtualization.h>

#ifdef __arm64__

@implementation MacOSRestoreImage

// MARK: Download the restore image from the network.

- (void)download:(void (^)(void))completionHandler
{
    [VZMacOSRestoreImage fetchLatestSupportedWithCompletionHandler:^(VZMacOSRestoreImage *restoreImage, NSError *error) {
        if (error) {
            abortWithErrorMessage([NSString stringWithFormat:@"Failed to fetch latest supported restore image catalog. %@", error.localizedDescription]);
        }

        NSLog(@"Attempting to download the latest available restore image.");
        NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:restoreImage.URL
                                                                                 completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                abortWithErrorMessage([NSString stringWithFormat:@"Failed to download restore image. %@", error.localizedDescription]);
            }

            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:getRestoreImageURL() error:&error]) {
                abortWithErrorMessage(error.localizedDescription);
            }

            completionHandler();
        }];

        [downloadTask.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
        [downloadTask resume];
    }];
}

// MARK: Observe the download progress.

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {
        NSProgress *progress = (NSProgress *)object;
        NSLog(@"Restore image download progress: %f.", progress.fractionCompleted * 100);

        if (progress.finished) {
            [progress removeObserver:self forKeyPath:@"fractionCompleted"];
        }
    }
}

@end

#endif
