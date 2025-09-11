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
