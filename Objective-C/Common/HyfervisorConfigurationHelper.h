/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The helper that creates various configuration objects exposed in the `VZVirtualMachineConfiguration`.
*/

#ifndef HyfervisorConfigurationHelper_h
#define HyfervisorConfigurationHelper_h

#import <Virtualization/Virtualization.h>

#ifdef __arm64__

@interface HyfervisorConfigurationHelper : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (NSUInteger)computeCPUCount;

+ (uint64_t)computeMemorySize;

+ (VZMacOSBootLoader *)createBootLoader;
+ (VZMacOSBootLoader *)createBootLoaderWithAVPBooterPath:(NSString *)avpBooterPath;
+ (BOOL)validateAVPBooterPath:(NSString *)avpBooterPath error:(NSError **)error;

+ (VZVirtioBlockDeviceConfiguration *)createBlockDeviceConfiguration;
+ (VZMacGraphicsDeviceConfiguration *)createGraphicsDeviceConfiguration;
+ (VZVirtioNetworkDeviceConfiguration *)createNetworkDeviceConfiguration;
+ (VZVirtioSoundDeviceConfiguration *)createSoundDeviceConfiguration;

+ (VZPointingDeviceConfiguration *)createPointingDeviceConfiguration;
+ (VZKeyboardConfiguration *)createKeyboardConfiguration;

@end

#endif /* __arm64__ */
#endif /* HyfervisorConfigurationHelper_h */
