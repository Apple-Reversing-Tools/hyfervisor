/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

#import "AppDelegate.h"

#import "Error.h"
#import "HyfervisorConfigurationHelper.h"
#import "HyfervisorDelegate.h"
#import "Path.h"

#import <Virtualization/Virtualization.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Debug stub protocols (based on VirtualApple implementation)
@protocol _VZGDBDebugStubConfiguration <NSObject>
- (instancetype)initWithPort:(NSInteger)port;
@end

@protocol _VZVirtualMachineConfiguration <NSObject>
@property (nonatomic, strong) id _debugStub;
@end

@interface AppDelegate ()

@property (weak) IBOutlet VZVirtualMachineView *virtualMachineView;

@property (strong) IBOutlet NSWindow *window;

// Hardware Configuration Properties (based on super-tart and VirtualApple)
@property (nonatomic, assign) NSInteger cpuCount;
@property (nonatomic, assign) UInt64 memorySize;
@property (nonatomic, assign) NSInteger displayWidth;
@property (nonatomic, assign) NSInteger displayHeight;
@property (nonatomic, assign) NSInteger debugPort;
@property (nonatomic, assign) BOOL debugEnabled;
@property (nonatomic, assign) BOOL consoleEnabled;
@property (nonatomic, assign) BOOL panicDeviceEnabled;
@property (nonatomic, assign) BOOL audioEnabled;
@property (nonatomic, assign) BOOL networkEnabled;
@property (nonatomic, strong) NSString *networkInterface;
@property (nonatomic, assign) UInt64 diskSize;

- (IBAction)normalRestart:(id)sender;
- (IBAction)recoveryRestart:(id)sender;

@end

@implementation AppDelegate {
    VZVirtualMachine *_virtualMachine;
    HyfervisorDelegate *_delegate;
}

#ifdef __arm64__

// MARK: Create the Mac platform configuration.

- (VZMacPlatformConfiguration *)createMacPlatformConfiguration
{
    VZMacPlatformConfiguration *macPlatformConfiguration = [[VZMacPlatformConfiguration alloc] init];
    VZMacAuxiliaryStorage *auxiliaryStorage = [[VZMacAuxiliaryStorage alloc] initWithContentsOfURL:getAuxiliaryStorageURL()];
    macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage;

    if (![[NSFileManager defaultManager] fileExistsAtPath:getVMBundlePath()]) {
        abortWithErrorMessage([NSString stringWithFormat:@"Missing Virtual Machine Bundle at %@. Run InstallationTool first to create it.", getVMBundlePath()]);
    }

    // Retrieve the hardware model and save this value to disk during installation.
    NSData *hardwareModelData = [[NSData alloc] initWithContentsOfURL:getHardwareModelURL()];
    if (!hardwareModelData) {
        abortWithErrorMessage(@"Failed to retrieve hardware model data.");
    }

    VZMacHardwareModel *hardwareModel = [[VZMacHardwareModel alloc] initWithDataRepresentation:hardwareModelData];
    if (!hardwareModel) {
        abortWithErrorMessage(@"Failed to create hardware model.");
    }

    if (!hardwareModel.supported) {
        abortWithErrorMessage(@"The hardware model isn't supported on the current host");
    }
    macPlatformConfiguration.hardwareModel = hardwareModel;

    // Retrieve the machine identifier and save this value to disk
    // during installation.
    NSData *machineIdentifierData = [[NSData alloc] initWithContentsOfURL:getMachineIdentifierURL()];
    if (!machineIdentifierData) {
        abortWithErrorMessage(@"Failed to retrieve machine identifier data.");
    }

    VZMacMachineIdentifier *machineIdentifier = [[VZMacMachineIdentifier alloc] initWithDataRepresentation:machineIdentifierData];
    if (!machineIdentifier) {
        abortWithErrorMessage(@"Failed to create machine identifier.");
    }
    macPlatformConfiguration.machineIdentifier = machineIdentifier;

    return macPlatformConfiguration;
}

// MARK: Create the virtual machine configuration and instantiate the virtual machine.

- (void)createVirtualMachine
{
    VZVirtualMachineConfiguration *configuration = [VZVirtualMachineConfiguration new];

    configuration.platform = [self createMacPlatformConfiguration];
    configuration.CPUCount = self.cpuCount;  // Use user-configured CPU count
    configuration.memorySize = self.memorySize;  // Use user-configured memory size

    configuration.bootLoader = [HyfervisorConfigurationHelper createBootLoader];

    // Audio devices (based on user settings)
    if (self.audioEnabled) {
        configuration.audioDevices = @[ [HyfervisorConfigurationHelper createSoundDeviceConfiguration] ];
    }
    
    // Graphics devices (based on user settings and super-tart implementation)
    VZMacGraphicsDeviceConfiguration *graphicsConfiguration = [[VZMacGraphicsDeviceConfiguration alloc] init];
    graphicsConfiguration.displays = @[
        [[VZMacGraphicsDisplayConfiguration alloc] initWithWidthInPixels:self.displayWidth 
                                                         heightInPixels:self.displayHeight 
                                                          pixelsPerInch:80]
    ];
    configuration.graphicsDevices = @[ graphicsConfiguration ];
    
    // Network devices (based on user settings)
    if (self.networkEnabled) {
        configuration.networkDevices = @[ [HyfervisorConfigurationHelper createNetworkDeviceConfiguration] ];
    }
    configuration.storageDevices = @[ [HyfervisorConfigurationHelper createBlockDeviceConfiguration] ];

    configuration.pointingDevices = @[ [HyfervisorConfigurationHelper createPointingDeviceConfiguration] ];
    configuration.keyboards = @[ [HyfervisorConfigurationHelper createKeyboardConfiguration] ];
    
    // Setup console device (based on super-tart implementation and user settings)
    if (self.consoleEnabled) {
        [self setupConsoleDeviceForConfiguration:configuration];
    }
    
    // Setup debug stub (based on super-tart implementation and user settings)
    if (self.debugEnabled) {
        [self setupDebugStubForConfiguration:configuration];
    }
    
    // Setup panic device (needed on macOS 14+ when setPanicAction is enabled) - super-tart method
    if (@available(macOS 14, *) && self.panicDeviceEnabled) {
        [self setupPanicDeviceForConfiguration:configuration];
    }
    
    // Validate configuration after debug stub setup (super-tart method)
    BOOL isValidConfiguration = [configuration validateWithError:nil];
    if (!isValidConfiguration) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Invalid configuration" userInfo:nil];
    }
    
    if (@available(macOS 14.0, *)) {
        BOOL supportsSaveRestore = [configuration validateSaveRestoreSupportWithError:nil];
        if (!supportsSaveRestore) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Invalid configuration" userInfo:nil];
        }
    }

    _virtualMachine = [[VZVirtualMachine alloc] initWithConfiguration:configuration];
}

// MARK: Setup debug stub for GDB debugging

- (void)setupDebugStubForConfiguration:(VZVirtualMachineConfiguration *)configuration
{
    NSLog(@"Setting up debug stub on port %ld...", (long)self.debugPort);
    
    @try {
        // Use super-tart method: Dynamic._VZGDBDebugStubConfiguration(port:)
        // This is equivalent to: let debugStub = Dynamic._VZGDBDebugStubConfiguration(port: vmConfig.debugPort)
        Class debugStubClass = NSClassFromString(@"_VZGDBDebugStubConfiguration");
        if (!debugStubClass) {
            NSLog(@"Warning: _VZGDBDebugStubConfiguration class not found");
            return;
        }
        
        // Create debug stub instance with user-configured port (super-tart method)
        // This is equivalent to: debugStub.port = self.debugPort
        id debugStub = [[debugStubClass alloc] initWithPort:self.debugPort];
        if (!debugStub) {
            NSLog(@"Warning: Failed to create debug stub instance");
            return;
        }
        
        // Use super-tart method: Dynamic(configuration)._setDebugStub(debugStub)
        // This is equivalent to: Dynamic(configuration)._setDebugStub(debugStub)
        id vmConfig = (__bridge id)(__bridge void*)configuration;
        
        // Call _setDebugStub method directly (super-tart method)
        // Using objc_msgSend for more direct method calling (like Dynamic library)
        SEL setDebugStubSelector = NSSelectorFromString(@"_setDebugStub:");
        if ([vmConfig respondsToSelector:setDebugStubSelector]) {
            // Use objc_msgSend for direct method calling (like Dynamic library)
            ((void (*)(id, SEL, id))objc_msgSend)(vmConfig, setDebugStubSelector, debugStub);
            NSLog(@"Debug stub successfully configured on port 8000");
        } else {
            NSLog(@"Warning: _setDebugStub method not found");
        }
        
    } @catch (NSException *exception) {
        NSLog(@"Warning: Failed to setup debug stub: %@", exception.reason);
    }
}

// MARK: Setup console device (based on super-tart implementation)

- (void)setupConsoleDeviceForConfiguration:(VZVirtualMachineConfiguration *)configuration
{
    NSLog(@"Setting up console device...");
    
    @try {
        // Create console port (super-tart method)
        VZVirtioConsolePortConfiguration *consolePort = [[VZVirtioConsolePortConfiguration alloc] init];
        consolePort.name = @"hyfervisor-version-1.0";
        
        // Create console device (super-tart method)
        VZVirtioConsoleDeviceConfiguration *consoleDevice = [[VZVirtioConsoleDeviceConfiguration alloc] init];
        consoleDevice.ports[0] = consolePort;
        
        // Add console device to configuration (super-tart method)
        NSMutableArray *consoleDevices = [configuration.consoleDevices mutableCopy];
        if (!consoleDevices) {
            consoleDevices = [[NSMutableArray alloc] init];
        }
        [consoleDevices addObject:consoleDevice];
        configuration.consoleDevices = [consoleDevices copy];
        
        NSLog(@"Console device successfully configured");
        
    } @catch (NSException *exception) {
        NSLog(@"Warning: Failed to setup console device: %@", exception.reason);
    }
}

// MARK: Setup panic device for macOS 14+

- (void)setupPanicDeviceForConfiguration:(VZVirtualMachineConfiguration *)configuration
{
    NSLog(@"Setting up panic device for macOS 14+...");
    
    @try {
        // Use super-tart method: Dynamic._VZPvPanicDeviceConfiguration()
        // This is equivalent to: let panicDevice = Dynamic._VZPvPanicDeviceConfiguration()
        Class panicDeviceClass = NSClassFromString(@"_VZPvPanicDeviceConfiguration");
        if (!panicDeviceClass) {
            NSLog(@"Warning: _VZPvPanicDeviceConfiguration class not found");
            return;
        }
        
        // Create panic device instance (super-tart method)
        // Try different initialization methods
        id panicDevice = nil;
        
        // Method 1: Standard alloc/init
        panicDevice = [[panicDeviceClass alloc] init];
        if (!panicDevice) {
            NSLog(@"Warning: Failed to create panic device instance with alloc/init");
            return;
        }
        
        // Use super-tart method: Dynamic(configuration)._setPanicDevice(panicDevice)
        // This is equivalent to: Dynamic(configuration)._setPanicDevice(panicDevice)
        id vmConfig = (__bridge id)(__bridge void*)configuration;
        
        // Call _setPanicDevice method directly (super-tart method)
        // Using objc_msgSend for more direct method calling (like Dynamic library)
        SEL setPanicDeviceSelector = NSSelectorFromString(@"_setPanicDevice:");
        if ([vmConfig respondsToSelector:setPanicDeviceSelector]) {
            // Use objc_msgSend for direct method calling (like Dynamic library)
            ((void (*)(id, SEL, id))objc_msgSend)(vmConfig, setPanicDeviceSelector, panicDevice);
            NSLog(@"Panic device successfully configured");
        } else {
            NSLog(@"Warning: _setPanicDevice method not found");
        }
        
    } @catch (NSException *exception) {
        NSLog(@"Warning: Failed to setup panic device: %@", exception.reason);
    }
}

// MARK: Start or restore the virtual machine.

- (void)startVirtualMachine
{
    [_virtualMachine startWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            abortWithErrorMessage([NSString stringWithFormat:@"%@%@", @"Virtual machine failed to start with ", error.localizedDescription]);
        }
    }];
}

- (void)resumeVirtualMachine
{
    [_virtualMachine resumeWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            abortWithErrorMessage([NSString stringWithFormat:@"%@%@", @"Virtual machine failed to resume with ", error.localizedDescription]);
        }
    }];
}

- (void)restoreVirtualMachine API_AVAILABLE(macosx(14.0));
{
    [_virtualMachine restoreMachineStateFromURL:getSaveFileURL() completionHandler:^(NSError * _Nullable error) {
        // Remove the saved file. Whether success or failure, the state no longer matches the VM's disk.
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtURL:getSaveFileURL() error:nil];

        if (!error) {
            [self resumeVirtualMachine];
        } else {
            [self startVirtualMachine];
        }
    }];
}
#endif

// MARK: Restart methods

- (IBAction)normalRestart:(id)sender
{
    [self restartVirtualMachine:NO];
}

- (IBAction)recoveryRestart:(id)sender
{
    [self restartVirtualMachine:YES];
}

- (void)restartVirtualMachine:(BOOL)recoveryMode
{
    if (!_virtualMachine || _virtualMachine.state != VZVirtualMachineStateRunning) {
        return;
    }

    // Stop the current virtual machine
    [_virtualMachine stopWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to stop virtual machine: %@", error.localizedDescription);
            return;
        }

        // Wait a moment for the VM to fully stop
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (recoveryMode) {
                [self startVirtualMachineInRecoveryMode];
            } else {
                [self startVirtualMachine];
            }
        });
    }];
}

- (void)startVirtualMachineInRecoveryMode
{
    NSLog(@"Attempting to start virtual machine in recovery mode...");
    
    // Based on VirtualApple's working implementation
    if (@available(macOS 13.0, *)) {
        // Use VZMacOSVirtualMachineStartOptions for macOS 13+
        @try {
            Class optionsClass = NSClassFromString(@"VZMacOSVirtualMachineStartOptions");
            if (optionsClass) {
                id options = [[optionsClass alloc] init];
                if (options && [options respondsToSelector:@selector(setStartUpFromMacOSRecovery:)]) {
                    [options performSelector:@selector(setStartUpFromMacOSRecovery:) withObject:@YES];
                    NSLog(@"Set startUpFromMacOSRecovery to YES");
                    
                    // Use startWithOptions:completionHandler: method
                    if ([_virtualMachine respondsToSelector:@selector(startWithOptions:completionHandler:)]) {
                        [_virtualMachine performSelector:@selector(startWithOptions:completionHandler:) 
                                              withObject:options 
                                              withObject:^(NSError *error) {
                            if (error) {
                                NSLog(@"Failed to start virtual machine in recovery mode: %@", error.localizedDescription);
                            } else {
                                NSLog(@"Virtual machine started in recovery mode (macOS 13+)");
                            }
                        }];
                        return;
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"macOS 13+ recovery mode failed: %@", exception.reason);
        }
    } else {
        // Use private _VZVirtualMachineStartOptions for macOS < 13
        @try {
            Class optionsClass = NSClassFromString(@"_VZVirtualMachineStartOptions");
            if (optionsClass) {
                id options = [[optionsClass alloc] init];
                if (options) {
                    // Set bootMacOSRecovery property
                    if ([options respondsToSelector:@selector(setBootMacOSRecovery:)]) {
                        [options performSelector:@selector(setBootMacOSRecovery:) withObject:@YES];
                        NSLog(@"Set bootMacOSRecovery to YES");
                    }
                    
                    // Use private _startWithOptions:completionHandler: method
                    if ([_virtualMachine respondsToSelector:@selector(_startWithOptions:completionHandler:)]) {
                        [_virtualMachine performSelector:@selector(_startWithOptions:completionHandler:) 
                                              withObject:options 
                                              withObject:^(NSError *error) {
                            if (error) {
                                NSLog(@"Failed to start virtual machine in recovery mode: %@", error.localizedDescription);
                            } else {
                                NSLog(@"Virtual machine started in recovery mode (macOS < 13)");
                            }
                        }];
                        return;
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"macOS < 13 recovery mode failed: %@", exception.reason);
        }
    }
    
    // Fallback to normal start if recovery mode fails
    NSLog(@"Recovery mode failed, falling back to normal start");
    [self startVirtualMachine];
}



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#ifdef __arm64__
    // Initialize hardware configuration with default values (based on super-tart and VirtualApple)
    [self initializeHardwareConfiguration];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createVirtualMachine];

        self->_delegate = [HyfervisorDelegate new];
        self->_virtualMachine.delegate = self->_delegate;
        self->_virtualMachineView.virtualMachine = self->_virtualMachine;
        self->_virtualMachineView.capturesSystemKeys = YES;

        if (@available(macOS 14.0, *)) {
            // Configure the app to automatically respond to changes in the display size.
            self->_virtualMachineView.automaticallyReconfiguresDisplay = YES;
        }

        if (@available(macOS 14.0, *)) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:getSaveFileURL().path]) {
                [self restoreVirtualMachine];
            } else {
                [self startVirtualMachine];
            }
        } else {
            [self startVirtualMachine];
        }
    });
#endif
}

// MARK: Save the virtual machine when the app exits.

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

#ifdef __arm64__
- (void)saveVirtualMachine:(void (^)(void))completionHandler API_AVAILABLE(macosx(14.0));
{
    [_virtualMachine saveMachineStateToURL:getSaveFileURL() completionHandler:^(NSError * _Nullable error) {
        if (error) {
            abortWithErrorMessage([NSString stringWithFormat:@"%@%@", @"Virtual machine failed to save with ", error.localizedDescription]);
        }
        
        completionHandler();
    }];
}

- (void)pauseAndSaveVirtualMachine:(void (^)(void))completionHandler API_AVAILABLE(macosx(14.0));
{
    [_virtualMachine pauseWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            abortWithErrorMessage([NSString stringWithFormat:@"%@%@", @"Virtual machine failed to pause with ", error.localizedDescription]);
        }

        [self saveVirtualMachine:completionHandler];
    }];
}
#endif

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
{
#ifdef __arm64__
    if (@available(macOS 14.0, *)) {
        if (_virtualMachine.state == VZVirtualMachineStateRunning) {
            [self pauseAndSaveVirtualMachine:^(void) {
                [sender replyToApplicationShouldTerminate:YES];
            }];
            
            return NSTerminateLater;
        }
    }
#endif

    return NSTerminateNow;
}

// MARK: Hardware Configuration Initialization

- (void)initializeHardwareConfiguration
{
    // Default values based on super-tart and VirtualApple
    self.cpuCount = 4;  // Default CPU count
    self.memorySize = 4ULL * 1024 * 1024 * 1024;  // 4GB default memory
    self.displayWidth = 1024;  // Default display width (super-tart default)
    self.displayHeight = 768;  // Default display height (super-tart default)
    self.debugPort = 8000;  // Default debug port (super-tart default)
    self.debugEnabled = YES;  // Debug enabled by default
    self.consoleEnabled = YES;  // Console enabled by default
    self.panicDeviceEnabled = YES;  // Panic device enabled by default (macOS 14+)
    self.audioEnabled = YES;  // Audio enabled by default
    self.networkEnabled = YES;  // Network enabled by default
    self.networkInterface = @"en0";  // Default network interface
    self.diskSize = 64ULL * 1024 * 1024 * 1024;  // 64GB default disk size
}

// MARK: Hardware Configuration Actions

- (IBAction)showCPUSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"CPU Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current CPU Count: %ld\nMaximum Available: %ld", 
                            (long)self.cpuCount, (long)[[NSProcessInfo processInfo] activeProcessorCount]];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showCPUSettingsWindow];
    }
}

- (IBAction)showMemorySettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Memory Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current Memory: %.1f GB\nMaximum Available: %.1f GB", 
                            (double)self.memorySize / (1024*1024*1024), 
                            (double)[[NSProcessInfo processInfo] physicalMemory] / (1024*1024*1024)];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showMemorySettingsWindow];
    }
}

- (IBAction)showDisplaySettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Display Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current Resolution: %ld x %ld", 
                            (long)self.displayWidth, (long)self.displayHeight];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showDisplaySettingsWindow];
    }
}

- (IBAction)showNetworkSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Network Settings";
    alert.informativeText = [NSString stringWithFormat:@"Network Enabled: %@\nInterface: %@", 
                            self.networkEnabled ? @"Yes" : @"No", self.networkInterface];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showNetworkSettingsWindow];
    }
}

- (IBAction)showStorageSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Storage Settings";
    alert.informativeText = [NSString stringWithFormat:@"Disk Size: %.1f GB", 
                            (double)self.diskSize / (1024*1024*1024)];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showStorageSettingsWindow];
    }
}

- (IBAction)showAudioSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Audio Settings";
    alert.informativeText = [NSString stringWithFormat:@"Audio Enabled: %@", 
                            self.audioEnabled ? @"Yes" : @"No"];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showAudioSettingsWindow];
    }
}

// MARK: Debug Configuration Actions

- (IBAction)showDebugPortSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Debug Port Settings";
    alert.informativeText = [NSString stringWithFormat:@"Debug Enabled: %@\nDebug Port: %ld", 
                            self.debugEnabled ? @"Yes" : @"No", (long)self.debugPort];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showDebugPortSettingsWindow];
    }
}

- (IBAction)showConsoleSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Console Settings";
    alert.informativeText = [NSString stringWithFormat:@"Console Enabled: %@", 
                            self.consoleEnabled ? @"Yes" : @"No"];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showConsoleSettingsWindow];
    }
}

- (IBAction)showAdvancedDebugSettings:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Advanced Debug Settings";
    alert.informativeText = [NSString stringWithFormat:@"Panic Device Enabled: %@\nConsole Enabled: %@\nDebug Enabled: %@", 
                            self.panicDeviceEnabled ? @"Yes" : @"No",
                            self.consoleEnabled ? @"Yes" : @"No",
                            self.debugEnabled ? @"Yes" : @"No"];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Change"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        [self showAdvancedDebugSettingsWindow];
    }
}

// MARK: Settings Window Methods (Placeholder implementations)

- (void)showCPUSettingsWindow
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"CPU Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current CPU Count: %ld\nMaximum Available: %ld", 
                            (long)self.cpuCount, (long)[[NSProcessInfo processInfo] activeProcessorCount]];
    
    // Add text field for CPU count input
    NSTextField *inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    inputField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.cpuCount];
    inputField.placeholderString = @"Enter CPU count";
    
    alert.accessoryView = inputField;
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSInteger newCpuCount = [inputField.stringValue integerValue];
        NSInteger maxCpu = [[NSProcessInfo processInfo] activeProcessorCount];
        
        if (newCpuCount > 0 && newCpuCount <= maxCpu) {
            self.cpuCount = newCpuCount;
            NSLog(@"CPU count updated to: %ld", (long)self.cpuCount);
            
            // Show confirmation
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"CPU Settings Updated";
            confirmAlert.informativeText = [NSString stringWithFormat:@"CPU count has been set to %ld cores.\nChanges will take effect on next VM restart.", (long)self.cpuCount];
            [confirmAlert addButtonWithTitle:@"OK"];
            [confirmAlert runModal];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid CPU Count";
            errorAlert.informativeText = [NSString stringWithFormat:@"Please enter a value between 1 and %ld", (long)maxCpu];
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
        }
    }
}

- (void)showMemorySettingsWindow
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Memory Settings";
    
    UInt64 maxMemory = [[NSProcessInfo processInfo] physicalMemory];
    double currentMemoryGB = (double)self.memorySize / (1024*1024*1024);
    double maxMemoryGB = (double)maxMemory / (1024*1024*1024);
    
    alert.informativeText = [NSString stringWithFormat:@"Current Memory: %.1f GB\nMaximum Available: %.1f GB", 
                            currentMemoryGB, maxMemoryGB];
    
    // Add text field for memory size input
    NSTextField *inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    inputField.stringValue = [NSString stringWithFormat:@"%.1f", currentMemoryGB];
    inputField.placeholderString = @"Enter memory size in GB";
    
    alert.accessoryView = inputField;
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        double newMemoryGB = [inputField.stringValue doubleValue];
        
        if (newMemoryGB > 0 && newMemoryGB <= maxMemoryGB) {
            self.memorySize = (UInt64)(newMemoryGB * 1024 * 1024 * 1024);
            NSLog(@"Memory size updated to: %.1f GB", newMemoryGB);
            
            // Show confirmation
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"Memory Settings Updated";
            confirmAlert.informativeText = [NSString stringWithFormat:@"Memory size has been set to %.1f GB.\nChanges will take effect on next VM restart.", newMemoryGB];
            [confirmAlert addButtonWithTitle:@"OK"];
            [confirmAlert runModal];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid Memory Size";
            errorAlert.informativeText = [NSString stringWithFormat:@"Please enter a value between 0.1 and %.1f GB", maxMemoryGB];
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
        }
    }
}

- (void)showDisplaySettingsWindow
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Display Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current Resolution: %ld x %ld", 
                            (long)self.displayWidth, (long)self.displayHeight];
    
    // Create a view with two text fields for width and height
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 60)];
    
    NSTextField *widthLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 35, 50, 20)];
    widthLabel.stringValue = @"Width:";
    widthLabel.editable = NO;
    widthLabel.bordered = NO;
    widthLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:widthLabel];
    
    NSTextField *widthField = [[NSTextField alloc] initWithFrame:NSMakeRect(70, 35, 100, 24)];
    widthField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.displayWidth];
    widthField.placeholderString = @"Width";
    widthField.tag = 100; // Tag for width field
    [accessoryView addSubview:widthField];
    
    NSTextField *heightLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(180, 35, 50, 20)];
    heightLabel.stringValue = @"Height:";
    heightLabel.editable = NO;
    heightLabel.bordered = NO;
    heightLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:heightLabel];
    
    NSTextField *heightField = [[NSTextField alloc] initWithFrame:NSMakeRect(240, 35, 100, 24)];
    heightField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.displayHeight];
    heightField.placeholderString = @"Height";
    heightField.tag = 101; // Tag for height field
    [accessoryView addSubview:heightField];
    
    // Add preset buttons
    NSButton *preset1 = [[NSButton alloc] initWithFrame:NSMakeRect(10, 5, 80, 25)];
    [preset1 setTitle:@"1024x768"];
    [preset1 setTarget:self];
    [preset1 setAction:@selector(setDisplayPreset1024x768:)];
    [accessoryView addSubview:preset1];
    
    NSButton *preset2 = [[NSButton alloc] initWithFrame:NSMakeRect(100, 5, 80, 25)];
    [preset2 setTitle:@"1920x1080"];
    [preset2 setTarget:self];
    [preset2 setAction:@selector(setDisplayPreset1920x1080:)];
    [accessoryView addSubview:preset2];
    
    NSButton *preset3 = [[NSButton alloc] initWithFrame:NSMakeRect(190, 5, 80, 25)];
    [preset3 setTitle:@"2560x1440"];
    [preset3 setTarget:self];
    [preset3 setAction:@selector(setDisplayPreset2560x1440:)];
    [accessoryView addSubview:preset3];
    
    alert.accessoryView = accessoryView;
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSTextField *widthField = [accessoryView viewWithTag:100];
        NSTextField *heightField = [accessoryView viewWithTag:101];
        
        NSInteger newWidth = [widthField.stringValue integerValue];
        NSInteger newHeight = [heightField.stringValue integerValue];
        
        if (newWidth > 0 && newHeight > 0 && newWidth <= 4096 && newHeight <= 4096) {
            self.displayWidth = newWidth;
            self.displayHeight = newHeight;
            NSLog(@"Display resolution updated to: %ld x %ld", (long)self.displayWidth, (long)self.displayHeight);
            
            // Show confirmation
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"Display Settings Updated";
            confirmAlert.informativeText = [NSString stringWithFormat:@"Display resolution has been set to %ld x %ld.\nChanges will take effect on next VM restart.", (long)self.displayWidth, (long)self.displayHeight];
            [confirmAlert addButtonWithTitle:@"OK"];
            [confirmAlert runModal];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid Display Resolution";
            errorAlert.informativeText = @"Please enter valid width and height values (1-4096)";
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
        }
    }
}

// MARK: Display Preset Methods

- (IBAction)setDisplayPreset1024x768:(id)sender
{
    self.displayWidth = 1024;
    self.displayHeight = 768;
    NSLog(@"Display preset set to 1024x768");
}

- (IBAction)setDisplayPreset1920x1080:(id)sender
{
    self.displayWidth = 1920;
    self.displayHeight = 1080;
    NSLog(@"Display preset set to 1920x1080");
}

- (IBAction)setDisplayPreset2560x1440:(id)sender
{
    self.displayWidth = 2560;
    self.displayHeight = 1440;
    NSLog(@"Display preset set to 2560x1440");
}

- (void)showNetworkSettingsWindow
{
    // TODO: Implement network settings window
    NSLog(@"Network Settings Window - Interface: %@", self.networkInterface);
}

- (void)showStorageSettingsWindow
{
    // TODO: Implement storage settings window
    NSLog(@"Storage Settings Window - Size: %.1f GB", (double)self.diskSize / (1024*1024*1024));
}

- (void)showAudioSettingsWindow
{
    // TODO: Implement audio settings window
    NSLog(@"Audio Settings Window - Enabled: %@", self.audioEnabled ? @"Yes" : @"No");
}

- (void)showDebugPortSettingsWindow
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Debug Port Settings";
    alert.informativeText = [NSString stringWithFormat:@"Current Debug Port: %ld\nDebug Enabled: %@", 
                            (long)self.debugPort, self.debugEnabled ? @"Yes" : @"No"];
    
    // Create a view with text field and checkbox
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 80)];
    
    // Debug enabled checkbox
    NSButton *debugCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(10, 50, 200, 20)];
    [debugCheckbox setButtonType:NSButtonTypeSwitch];
    [debugCheckbox setTitle:@"Enable Debug Stub"];
    [debugCheckbox setState:self.debugEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    debugCheckbox.tag = 200; // Tag for debug checkbox
    [accessoryView addSubview:debugCheckbox];
    
    // Port label and field
    NSTextField *portLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 25, 80, 20)];
    portLabel.stringValue = @"Debug Port:";
    portLabel.editable = NO;
    portLabel.bordered = NO;
    portLabel.backgroundColor = [NSColor clearColor];
    [accessoryView addSubview:portLabel];
    
    NSTextField *portField = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 25, 100, 24)];
    portField.stringValue = [NSString stringWithFormat:@"%ld", (long)self.debugPort];
    portField.placeholderString = @"Port number";
    portField.tag = 201; // Tag for port field
    [accessoryView addSubview:portField];
    
    // Preset buttons
    NSButton *preset1 = [[NSButton alloc] initWithFrame:NSMakeRect(10, 5, 60, 20)];
    [preset1 setTitle:@"8000"];
    [preset1 setTarget:self];
    [preset1 setAction:@selector(setDebugPort8000:)];
    [accessoryView addSubview:preset1];
    
    NSButton *preset2 = [[NSButton alloc] initWithFrame:NSMakeRect(80, 5, 60, 20)];
    [preset2 setTitle:@"5555"];
    [preset2 setTarget:self];
    [preset2 setAction:@selector(setDebugPort5555:)];
    [accessoryView addSubview:preset2];
    
    NSButton *preset3 = [[NSButton alloc] initWithFrame:NSMakeRect(150, 5, 60, 20)];
    [preset3 setTitle:@"8890"];
    [preset3 setTarget:self];
    [preset3 setAction:@selector(setDebugPort8890:)];
    [accessoryView addSubview:preset3];
    
    alert.accessoryView = accessoryView;
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSButton *debugCheckbox = [accessoryView viewWithTag:200];
        NSTextField *portField = [accessoryView viewWithTag:201];
        
        self.debugEnabled = (debugCheckbox.state == NSControlStateValueOn);
        NSInteger newPort = [portField.stringValue integerValue];
        
        if (newPort > 0 && newPort <= 65535) {
            self.debugPort = newPort;
            NSLog(@"Debug settings updated - Enabled: %@, Port: %ld", 
                  self.debugEnabled ? @"Yes" : @"No", (long)self.debugPort);
            
            // Show confirmation
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"Debug Settings Updated";
            confirmAlert.informativeText = [NSString stringWithFormat:@"Debug stub: %@\nDebug port: %ld\nChanges will take effect on next VM restart.", 
                                          self.debugEnabled ? @"Enabled" : @"Disabled", (long)self.debugPort];
            [confirmAlert addButtonWithTitle:@"OK"];
            [confirmAlert runModal];
        } else {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid Debug Port";
            errorAlert.informativeText = @"Please enter a valid port number (1-65535)";
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
        }
    }
}

// MARK: Debug Port Preset Methods

- (IBAction)setDebugPort8000:(id)sender
{
    self.debugPort = 8000;
    NSLog(@"Debug port preset set to 8000");
}

- (IBAction)setDebugPort5555:(id)sender
{
    self.debugPort = 5555;
    NSLog(@"Debug port preset set to 5555");
}

- (IBAction)setDebugPort8890:(id)sender
{
    self.debugPort = 8890;
    NSLog(@"Debug port preset set to 8890");
}

- (void)showConsoleSettingsWindow
{
    // TODO: Implement console settings window
    NSLog(@"Console Settings Window - Enabled: %@", self.consoleEnabled ? @"Yes" : @"No");
}

- (void)showAdvancedDebugSettingsWindow
{
    // TODO: Implement advanced debug settings window
    NSLog(@"Advanced Debug Settings Window - Panic: %@, Console: %@, Debug: %@", 
          self.panicDeviceEnabled ? @"Yes" : @"No",
          self.consoleEnabled ? @"Yes" : @"No",
          self.debugEnabled ? @"Yes" : @"No");
}

@end
