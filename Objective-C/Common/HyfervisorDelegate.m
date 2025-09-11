/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class that conforms to `VZVirtualMachineDelegate` and tracks the virtual machine's state.
*/

#import "HyfervisorDelegate.h"

#import <AppKit/AppKit.h>

@implementation HyfervisorDelegate

- (void)virtualMachine:(VZVirtualMachine *)virtualMachine didStopWithError:(NSError *)error
{
    NSLog(@"Virtual Machine did stop with error. %@", error.localizedDescription);
    exit(-1);
}

- (void)guestDidStopVirtualMachine:(VZVirtualMachine *)virtualMachine
{
    NSLog(@"Guest did stop virtual machine.");
    exit(0);
}

@end
