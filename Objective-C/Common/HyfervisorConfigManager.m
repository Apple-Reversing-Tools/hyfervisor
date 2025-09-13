//
//  HyfervisorConfigManager.m
//  hyfervisor
//
//  Created by AI Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "HyfervisorConfigManager.h"

static HyfervisorConfigManager *sharedManager = nil;

@implementation HyfervisorConfigManager

+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self resetToDefaults];
    }
    return self;
}

#pragma mark - Configuration Management

- (BOOL)loadConfiguration
{
    NSString *configPath = [self getConfigFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:configPath]) {
        NSLog(@"Configuration file not found at %@, using defaults", configPath);
        return NO;
    }
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (!config) {
        NSLog(@"Failed to load configuration from %@", configPath);
        return NO;
    }
    
    // Load configuration values
    self.cpuCount = [config[@"cpuCount"] integerValue] ?: 4;
    self.memorySize = [config[@"memorySize"] unsignedLongLongValue] ?: (4ULL * 1024 * 1024 * 1024);
    self.displayWidth = [config[@"displayWidth"] integerValue] ?: 1024;
    self.displayHeight = [config[@"displayHeight"] integerValue] ?: 768;
    self.debugPort = [config[@"debugPort"] integerValue] ?: 8000;
    self.debugEnabled = [config[@"debugEnabled"] boolValue];
    self.consoleEnabled = [config[@"consoleEnabled"] boolValue];
    self.panicDeviceEnabled = [config[@"panicDeviceEnabled"] boolValue];
    self.audioEnabled = [config[@"audioEnabled"] boolValue];
    self.networkEnabled = [config[@"networkEnabled"] boolValue];
    self.networkInterface = config[@"networkInterface"] ?: @"en0";
    self.diskSize = [config[@"diskSize"] unsignedLongLongValue] ?: (64ULL * 1024 * 1024 * 1024);
    self.avpBooterPath = config[@"avpBooterPath"] ?: @"/System/Library/Frameworks/Virtualization.framework/Versions/A/Resources/AVPBooter.vmapple2.bin";
    
    NSLog(@"Configuration loaded successfully from %@", configPath);
    return YES;
}

- (BOOL)saveConfiguration
{
    NSString *configPath = [self getConfigFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Create config directory if it doesn't exist
    NSString *configDir = [configPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:configDir]) {
        NSError *error;
        if (![fileManager createDirectoryAtPath:configDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create config directory: %@", error.localizedDescription);
            return NO;
        }
    }
    
    // Create configuration dictionary
    NSDictionary *config = @{
        @"cpuCount": @(self.cpuCount),
        @"memorySize": @(self.memorySize),
        @"displayWidth": @(self.displayWidth),
        @"displayHeight": @(self.displayHeight),
        @"debugPort": @(self.debugPort),
        @"debugEnabled": @(self.debugEnabled),
        @"consoleEnabled": @(self.consoleEnabled),
        @"panicDeviceEnabled": @(self.panicDeviceEnabled),
        @"audioEnabled": @(self.audioEnabled),
        @"networkEnabled": @(self.networkEnabled),
        @"networkInterface": self.networkInterface ?: @"en0",
        @"diskSize": @(self.diskSize),
        @"avpBooterPath": self.avpBooterPath ?: @"/System/Library/Frameworks/Virtualization.framework/Versions/A/Resources/AVPBooter.vmapple2.bin"
    };
    
    // Save configuration to file
    BOOL success = [config writeToFile:configPath atomically:YES];
    if (success) {
        NSLog(@"Configuration saved successfully to %@", configPath);
    } else {
        NSLog(@"Failed to save configuration to %@", configPath);
    }
    
    return success;
}

- (void)resetToDefaults
{
    // Default values based on super-tart and VirtualApple
    self.cpuCount = 4;
    self.memorySize = 4ULL * 1024 * 1024 * 1024;  // 4GB
    self.displayWidth = 1024;
    self.displayHeight = 768;
    self.debugPort = 8000;
    self.debugEnabled = YES;
    self.consoleEnabled = YES;
    self.panicDeviceEnabled = YES;
    self.audioEnabled = YES;
    self.networkEnabled = YES;
    self.networkInterface = @"en0";
    self.diskSize = 64ULL * 1024 * 1024 * 1024;  // 64GB
    self.avpBooterPath = @"/System/Library/Frameworks/Virtualization.framework/Versions/A/Resources/AVPBooter.vmapple2.bin";
    
    NSLog(@"Configuration reset to defaults");
}

- (NSString *)getConfigFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = [paths firstObject];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *configDir = [appSupportDir stringByAppendingPathComponent:appName];
    return [configDir stringByAppendingPathComponent:@"hyfervisor_config.plist"];
}

@end
