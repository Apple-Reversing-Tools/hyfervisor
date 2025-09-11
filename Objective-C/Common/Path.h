/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A helper function to retrieve the various file URLs that this sample code uses.
*/

#ifndef Path_h
#define Path_h

#import <Foundation/Foundation.h>

static inline NSString *getVMBundlePath(void)
{
    return [NSString stringWithFormat:@"%@%@", NSHomeDirectory(), @"/VM.bundle/"];
}

static inline NSURL *getVMBundleURL(void)
{
    return [[NSURL alloc] initFileURLWithPath:getVMBundlePath()];
}

static inline NSURL *getAuxiliaryStorageURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"AuxiliaryStorage"];
}

static inline NSURL *getDiskImageURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"Disk.img"];
}

static inline NSURL *getHardwareModelURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"HardwareModel"];
}

static inline NSURL *getMachineIdentifierURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"MachineIdentifier"];
}

static inline NSURL *getRestoreImageURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"RestoreImage.ipsw"];
}

static inline NSURL *getSaveFileURL(void)
{
    return [getVMBundleURL() URLByAppendingPathComponent:@"SaveFile.vzvmsave"];
}

#endif /* Path_h */
