/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class that conforms to `VZVirtualMachineDelegate` and tracks the virtual machine's state.
*/

#ifndef HyfervisorDelegate_h
#define HyfervisorDelegate_h

#import <Virtualization/Virtualization.h>

@interface HyfervisorDelegate : NSObject<VZVirtualMachineDelegate>

@end

#endif /* HyfervisorDelegate_h */
