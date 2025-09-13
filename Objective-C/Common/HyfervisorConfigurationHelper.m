/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The helper that creates various configuration objects exposed in the `VZVirtualMachineConfiguration`.
*/

#import "HyfervisorConfigurationHelper.h"

#import "Error.h"
#import "Path.h"

#ifdef __arm64__

@implementation HyfervisorConfigurationHelper

+ (NSUInteger)computeCPUCount
{
    NSUInteger totalAvailableCPUs = [[NSProcessInfo processInfo] processorCount];
    NSUInteger virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1;
    virtualCPUCount = MAX(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount);
    virtualCPUCount = MIN(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount);

    return virtualCPUCount;
}

+ (uint64_t)computeMemorySize
{
    // Set the amount of system memory to 4 GB; this is a baseline value that you can change depending on your use case.
    uint64_t memorySize = 4ull * 1024ull * 1024ull * 1024ull;
    memorySize = MAX(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize);
    memorySize = MIN(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize);

    return memorySize;
}

+ (VZMacOSBootLoader *)createBootLoader
{
    return [[VZMacOSBootLoader alloc] init];
}

+ (VZMacOSBootLoader *)createBootLoaderWithAVPBooterPath:(NSString *)avpBooterPath
{
    VZMacOSBootLoader *bootLoader = [[VZMacOSBootLoader alloc] init];
    
    // Check if custom AVPBooter path is provided
    if (avpBooterPath && avpBooterPath.length > 0) {
        // Validate the AVPBooter path
        NSError *validationError;
        BOOL isValid = [self validateAVPBooterPath:avpBooterPath error:&validationError];
        
        if (isValid) {
            NSLog(@"Using custom AVPBooter: %@", avpBooterPath);
            
            // Use private API to set custom AVPBooter (based on super-tart implementation)
            @try {
                // Try to set the custom AVPBooter using private API
                // This is equivalent to: bootLoader.romURL = URL(fileURLWithPath: avpBooterPath)
                NSURL *romURL = [NSURL fileURLWithPath:avpBooterPath];
                
                // Use KVC to set the romURL property directly (super-tart method)
                [bootLoader setValue:romURL forKey:@"romURL"];
                NSLog(@"Successfully set custom AVPBooter ROM URL: %@", romURL);
            } @catch (NSException *exception) {
                NSLog(@"Warning: Failed to set custom AVPBooter: %@", exception.reason);
            }
        } else {
            NSLog(@"Warning: Invalid AVPBooter path: %@ - %@", avpBooterPath, validationError.localizedDescription);
        }
    }
    
    return bootLoader;
}

+ (BOOL)validateAVPBooterPath:(NSString *)avpBooterPath error:(NSError **)error
{
    if (!avpBooterPath || avpBooterPath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1001 
                                    userInfo:@{NSLocalizedDescriptionKey: @"AVPBooter path cannot be empty"}];
        }
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Check if file exists
    if (![fileManager fileExistsAtPath:avpBooterPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1002 
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"AVPBooter file not found at path: %@", avpBooterPath]}];
        }
        return NO;
    }
    
    // Check if it's a file (not a directory)
    BOOL isDirectory;
    [fileManager fileExistsAtPath:avpBooterPath isDirectory:&isDirectory];
    if (isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1003 
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Path is a directory, not a file: %@", avpBooterPath]}];
        }
        return NO;
    }
    
    // Check file extension (should be .bin)
    NSString *fileExtension = [avpBooterPath pathExtension];
    if (![fileExtension isEqualToString:@"bin"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1004 
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File does not have .bin extension: %@", avpBooterPath]}];
        }
        return NO;
    }
    
    // Check file size (should be reasonable for a bootloader)
    NSError *fileError;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:avpBooterPath error:&fileError];
    if (fileError) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1005 
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot read file attributes: %@", fileError.localizedDescription]}];
        }
        return NO;
    }
    
    NSNumber *fileSize = fileAttributes[NSFileSize];
    if (fileSize) {
        NSUInteger sizeInBytes = [fileSize unsignedIntegerValue];
        // AVPBooter should be at least 1KB and at most 100MB
        if (sizeInBytes < 1024 || sizeInBytes > 100 * 1024 * 1024) {
            if (error) {
                *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                            code:1006 
                                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File size is not reasonable for AVPBooter (%lu bytes): %@", (unsigned long)sizeInBytes, avpBooterPath]}];
            }
            return NO;
        }
    }
    
    // Check if file is readable
    if (![fileManager isReadableFileAtPath:avpBooterPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"HyfervisorConfigurationHelper" 
                                        code:1007 
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File is not readable: %@", avpBooterPath]}];
        }
        return NO;
    }
    
    return YES;
}

+ (VZVirtioBlockDeviceConfiguration *)createBlockDeviceConfiguration
{
    NSError *error;
    VZDiskImageStorageDeviceAttachment *diskAttachment = [[VZDiskImageStorageDeviceAttachment alloc] initWithURL:getDiskImageURL() readOnly:NO error:&error];
    if (!diskAttachment) {
        abortWithErrorMessage([NSString stringWithFormat:@"Failed to create VZDiskImageStorageDeviceAttachment. %@", error.localizedDescription]);
    }
    VZVirtioBlockDeviceConfiguration *disk = [[VZVirtioBlockDeviceConfiguration alloc] initWithAttachment:diskAttachment];

    return disk;
}

+ (VZMacGraphicsDeviceConfiguration *)createGraphicsDeviceConfiguration
{
    VZMacGraphicsDeviceConfiguration *graphicsConfiguration = [[VZMacGraphicsDeviceConfiguration alloc] init];
    graphicsConfiguration.displays = @[
        // The system arbitrarily chooses the resolution of the display to be 1920 x 1200.
        [[VZMacGraphicsDisplayConfiguration alloc] initWithWidthInPixels:1920 heightInPixels:1200 pixelsPerInch:80],
    ];

    return graphicsConfiguration;
}

+ (VZVirtioNetworkDeviceConfiguration *)createNetworkDeviceConfiguration
{
    VZVirtioNetworkDeviceConfiguration *networkConfiguration = [[VZVirtioNetworkDeviceConfiguration alloc] init];
    networkConfiguration.MACAddress = [[VZMACAddress alloc] initWithString:@"d6:a7:58:8e:78:d5"];

    VZNATNetworkDeviceAttachment *natAttachment = [[VZNATNetworkDeviceAttachment alloc] init];
    networkConfiguration.attachment = natAttachment;

    return networkConfiguration;
}

+ (VZVirtioSoundDeviceConfiguration *)createSoundDeviceConfiguration
{
    VZVirtioSoundDeviceConfiguration *audioDeviceConfiguration = [[VZVirtioSoundDeviceConfiguration alloc] init];

    VZVirtioSoundDeviceInputStreamConfiguration *inputStream = [[VZVirtioSoundDeviceInputStreamConfiguration alloc] init];
    inputStream.source = [[VZHostAudioInputStreamSource alloc] init];

    VZVirtioSoundDeviceOutputStreamConfiguration *outputStream = [[VZVirtioSoundDeviceOutputStreamConfiguration alloc] init];
    outputStream.sink = [[VZHostAudioOutputStreamSink alloc] init];

    audioDeviceConfiguration.streams = @[ inputStream, outputStream ];

    return audioDeviceConfiguration;
}

+ (VZPointingDeviceConfiguration *)createPointingDeviceConfiguration
{
    return [[VZMacTrackpadConfiguration alloc] init];
}

+ (VZKeyboardConfiguration *)createKeyboardConfiguration
{
    if (@available(macOS 14.0, *)) {
        return [[VZMacKeyboardConfiguration alloc] init];
    } else {
        return [[VZUSBKeyboardConfiguration alloc] init];
    }
}

@end

#endif
