/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Download the latest macOS restore image from the network.
*/

#ifndef MacOSRestoreImage_h
#define MacOSRestoreImage_h

#import <Foundation/Foundation.h>

#ifdef __arm64__

@interface MacOSRestoreImage : NSObject

- (void)download:(void (^)(void))completionHandler;

@end

#endif /* __arm64__ */
#endif /* MacOSRestoreImage_h */
