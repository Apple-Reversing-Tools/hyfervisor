//
//  HyfervisorConfigManager.h
//  hyfervisor
//
//  Created by AI Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HyfervisorConfigManager : NSObject

+ (instancetype)sharedManager;

// Configuration Properties
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
@property (nonatomic, strong) NSString *avpBooterPath;

// Configuration Management
- (BOOL)loadConfiguration;
- (BOOL)saveConfiguration;
- (void)resetToDefaults;
- (NSString *)getConfigFilePath;

@end

NS_ASSUME_NONNULL_END
