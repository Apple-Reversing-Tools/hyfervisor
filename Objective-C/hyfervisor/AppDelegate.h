/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

#import <Cocoa/Cocoa.h>
#import <Virtualization/Virtualization.h>

@class VZMacPlatformConfiguration;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (void)startVirtualMachine;
- (void)resumeVirtualMachine;
- (void)restartVirtualMachine:(BOOL)recoveryMode;
- (void)startVirtualMachineInRecoveryMode;
- (void)setupConsoleDeviceForConfiguration:(VZVirtualMachineConfiguration *)configuration;
- (void)setupDebugStubForConfiguration:(VZVirtualMachineConfiguration *)configuration;
- (void)setupPanicDeviceForConfiguration:(VZVirtualMachineConfiguration *)configuration;

// AVPBooter Configuration Actions
- (IBAction)showAVPBooterSettings:(id)sender;

// Hardware Configuration Actions
- (IBAction)showCPUSettings:(id)sender;
- (IBAction)showMemorySettings:(id)sender;
- (IBAction)showDisplaySettings:(id)sender;
- (IBAction)showNetworkSettings:(id)sender;
- (IBAction)showStorageSettings:(id)sender;
- (IBAction)showAudioSettings:(id)sender;

// Debug Configuration Actions
- (IBAction)showDebugPortSettings:(id)sender;
- (IBAction)showConsoleSettings:(id)sender;
- (IBAction)showAdvancedDebugSettings:(id)sender;

// Restart Actions
- (IBAction)normalRestart:(id)sender;
- (IBAction)recoveryRestart:(id)sender;

@end
