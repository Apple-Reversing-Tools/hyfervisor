/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The helper function that displays errors and aborts the program.
*/

#import <Foundation/Foundation.h>

static inline void abortWithErrorMessage(NSString *errorMessage)
{
    NSLog(@"%@", errorMessage);
    abort();
}
