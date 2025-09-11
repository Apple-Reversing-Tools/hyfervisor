/*
LICENSE.txt 파일을 참조하세요.

요약:
macOS 가상머신 설치를 위한 헬퍼 클래스입니다.
*/

#ifdef __arm64__  // Apple Silicon Mac에서만 컴파일

#import "HyfervisorInstaller.h"  // 헤더 파일 임포트

#import "Error.h"  // 에러 처리 헬퍼 함수들
#import "HyfervisorConfigurationHelper.h"  // hyfervisor 설정 헬퍼
#import "HyfervisorDelegate.h"  // hyfervisor 델리게이트
#import "Path.h"  // 경로 관련 헬퍼 함수들

#import <Foundation/Foundation.h>  // Foundation 프레임워크
#import <sys/stat.h>  // 시스템 상태 헤더
#import <Virtualization/Virtualization.h>  // 가상화 프레임워크

@implementation HyfervisorInstaller {  // hyfervisor 설치 클래스 구현
    VZVirtualMachine *_virtualMachine;  // 가상머신 인스턴스
    HyfervisorDelegate *_delegate;  // hyfervisor 델리게이트
}

// MARK: - 내부 헬퍼 메서드들

static void createVMBundle(void)  // VM 번들 생성 함수
{
    NSError *error;  // 에러 객체
    BOOL bundleCreateResult = [[NSFileManager defaultManager] createDirectoryAtURL:getVMBundleURL()  // VM 번들 URL에 디렉토리 생성
                                                       withIntermediateDirectories:NO  // 중간 디렉토리 생성 안함
                                                                        attributes:nil  // 기본 속성 사용
                                                                             error:&error];  // 에러 처리
    if (!bundleCreateResult) {  // 번들 생성 실패 시
        abortWithErrorMessage([error description]);  // 에러 메시지와 함께 프로그램 종료
    }
}

// 가상화 프레임워크는 두 가지 디스크 이미지 형식을 지원합니다:
// * RAW 디스크 이미지: 파일의 오프셋과 VM 디스크의 오프셋이 1:1 매핑되는 파일입니다.
//   RAW 디스크 이미지의 논리적 크기는 디스크 자체의 크기입니다.
//
//   이미지 파일이 APFS 볼륨에 저장된 경우, APFS의 스파스 파일 기능 덕분에
//   파일이 더 적은 공간을 차지합니다.
//
// * ASIF 디스크 이미지: 스파스 이미지 형식입니다. 호스트나 디스크 간에 ASIF 파일을
//   더 효율적으로 전송할 수 있습니다. 스파스성이 호스트의 파일시스템 기능에 의존하지 않기 때문입니다.
//
// 프레임워크는 macOS 16부터 ASIF를 지원합니다.
static void createASIFDiskImage(void)  // ASIF 디스크 이미지 생성 함수
{
    NSError *error = nil;  // 에러 객체 초기화
    NSTask *task = [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/sbin/diskutil"]  // diskutil 실행 파일 URL
                                               arguments:@[@"image", @"create", @"blank", @"--fs", @"none", @"--format", @"ASIF", @"--size", @"128GiB", getDiskImageURL().path]  // diskutil 인자들
                                                   error:&error  // 에러 처리
                                      terminationHandler:nil];  // 종료 핸들러

    if (error != nil) {  // 에러 발생 시
        abortWithErrorMessage([NSString stringWithFormat:@"diskutil 실행 실패: %@", error]);  // 에러 메시지와 함께 프로그램 종료
    }

    [task waitUntilExit];  // 작업 완료까지 대기
    if (task.terminationStatus != 0) {  // 작업 실패 시
        abortWithErrorMessage(@"디스크 이미지 생성 실패.");  // 에러 메시지와 함께 프로그램 종료
    }
}

static void createRAWDiskImage(void)  // RAW 디스크 이미지 생성 함수
{
    int fd = open([getDiskImageURL() fileSystemRepresentation], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);  // 디스크 이미지 파일 열기
    if (fd == -1) {  // 파일 열기 실패 시
        abortWithErrorMessage(@"디스크 이미지를 생성할 수 없습니다.");  // 에러 메시지와 함께 프로그램 종료
    }

    // 128 GB 디스크 공간
    int result = ftruncate(fd, 128ull * 1024ull * 1024ull * 1024ull);  // 파일 크기를 128GB로 설정
    if (result) {  // 크기 설정 실패 시
        abortWithErrorMessage(@"ftruncate() 실패.");  // 에러 메시지와 함께 프로그램 종료
    }

    result = close(fd);  // 파일 닫기
    if (result) {  // 파일 닫기 실패 시
        abortWithErrorMessage(@"디스크 이미지 닫기 실패.");  // 에러 메시지와 함께 프로그램 종료
    }
}

static void createDiskImage(void)  // 디스크 이미지 생성 함수
{
    if (@available(macOS 16.0, *)) {  // macOS 16.0 이상인 경우
        createASIFDiskImage();  // ASIF 디스크 이미지 생성
    } else {  // 그 외의 경우
        createRAWDiskImage();  // RAW 디스크 이미지 생성
    }
}

// MARK: Mac 플랫폼 설정 생성

- (VZMacPlatformConfiguration *)createMacPlatformConfiguration:(VZMacOSConfigurationRequirements *)macOSConfiguration  // Mac 플랫폼 설정 생성 메서드
{
    VZMacPlatformConfiguration *macPlatformConfiguration = [[VZMacPlatformConfiguration alloc] init];  // Mac 플랫폼 설정 객체 생성

    NSError *error;  // 에러 객체
    VZMacAuxiliaryStorage *auxiliaryStorage = [[VZMacAuxiliaryStorage alloc] initCreatingStorageAtURL:getAuxiliaryStorageURL()  // 보조 저장소 생성
                                                                                        hardwareModel:macOSConfiguration.hardwareModel  // 하드웨어 모델
                                                                                              options:VZMacAuxiliaryStorageInitializationOptionAllowOverwrite  // 덮어쓰기 옵션
                                                                                                error:&error];  // 에러 처리
    if (!auxiliaryStorage) {  // 보조 저장소 생성 실패 시
        abortWithErrorMessage([NSString stringWithFormat:@"보조 저장소 생성 실패. %@", error.localizedDescription]);  // 에러 메시지와 함께 프로그램 종료
    }

    macPlatformConfiguration.hardwareModel = macOSConfiguration.hardwareModel;  // 하드웨어 모델 설정
    macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage;  // 보조 저장소 설정
    macPlatformConfiguration.machineIdentifier = [[VZMacMachineIdentifier alloc] init];  // 머신 식별자 생성

    // 하드웨어 모델과 머신 식별자를 디스크에 저장하여 후속 부팅 시 검색할 수 있도록 합니다.
    [macPlatformConfiguration.hardwareModel.dataRepresentation writeToURL:getHardwareModelURL() atomically:YES];  // 하드웨어 모델 저장
    [macPlatformConfiguration.machineIdentifier.dataRepresentation writeToURL:getMachineIdentifierURL() atomically:YES];  // 머신 식별자 저장

    return macPlatformConfiguration;  // Mac 플랫폼 설정 반환
}

// MARK: 가상머신 설정 생성 및 가상머신 인스턴스화

- (void)setupVirtualMachineWithMacOSConfigurationRequirements:(VZMacOSConfigurationRequirements *)macOSConfiguration  // macOS 설정 요구사항으로 가상머신 설정 메서드
{
    VZVirtualMachineConfiguration *configuration = [VZVirtualMachineConfiguration new];  // 가상머신 설정 객체 생성

    configuration.platform = [self createMacPlatformConfiguration:macOSConfiguration];  // Mac 플랫폼 설정
    assert(configuration.platform);  // 플랫폼 설정 확인

    configuration.CPUCount = [HyfervisorConfigurationHelper computeCPUCount];  // CPU 개수 계산
    if (configuration.CPUCount < macOSConfiguration.minimumSupportedCPUCount) {  // 최소 지원 CPU 개수보다 적은 경우
        abortWithErrorMessage(@"CPU 개수가 macOS 설정에서 지원되지 않습니다.");  // 에러 메시지와 함께 프로그램 종료
    }

    configuration.memorySize = [HyfervisorConfigurationHelper computeMemorySize];  // 메모리 크기 계산
    if (configuration.memorySize < macOSConfiguration.minimumSupportedMemorySize) {  // 최소 지원 메모리 크기보다 적은 경우
        abortWithErrorMessage(@"메모리 크기가 macOS 설정에서 지원되지 않습니다.");  // 에러 메시지와 함께 프로그램 종료
    }

    // 128 GB 디스크 이미지 생성
    createDiskImage();  // 디스크 이미지 생성 함수 호출

    configuration.bootLoader = [HyfervisorConfigurationHelper createBootLoader];  // 부트로더 설정

    configuration.audioDevices = @[ [HyfervisorConfigurationHelper createSoundDeviceConfiguration] ];  // 오디오 장치 설정
    configuration.graphicsDevices = @[ [HyfervisorConfigurationHelper createGraphicsDeviceConfiguration] ];  // 그래픽 장치 설정
    configuration.networkDevices = @[ [HyfervisorConfigurationHelper createNetworkDeviceConfiguration] ];  // 네트워크 장치 설정
    configuration.storageDevices = @[ [HyfervisorConfigurationHelper createBlockDeviceConfiguration] ];  // 저장 장치 설정

    configuration.pointingDevices = @[ [HyfervisorConfigurationHelper createPointingDeviceConfiguration] ];  // 포인팅 장치 설정
    configuration.keyboards = @[ [HyfervisorConfigurationHelper createKeyboardConfiguration] ];  // 키보드 설정
    
    BOOL isValidConfiguration = [configuration validateWithError:nil];  // 설정 유효성 검사
    if (!isValidConfiguration) {  // 유효하지 않은 설정인 경우
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"잘못된 설정" userInfo:nil];  // 예외 발생
    }
    
    if (@available(macOS 14.0, *)) {  // macOS 14.0 이상인 경우
        BOOL supportsSaveRestore = [configuration validateSaveRestoreSupportWithError:nil];  // 저장/복원 지원 검사
        if (!supportsSaveRestore) {  // 저장/복원을 지원하지 않는 경우
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"잘못된 설정" userInfo:nil];  // 예외 발생
        }
    }

    self->_virtualMachine = [[VZVirtualMachine alloc] initWithConfiguration:configuration];  // 가상머신 인스턴스 생성
    self->_delegate = [HyfervisorDelegate new];  // 델리게이트 인스턴스 생성
    self->_virtualMachine.delegate = self->_delegate;  // 델리게이트 설정
}

- (void)startInstallationWithRestoreImageFileURL:(NSURL *)restoreImageFileURL  // 복원 이미지 파일 URL로 설치 시작 메서드
{
    VZMacOSInstaller *installer = [[VZMacOSInstaller alloc] initWithVirtualMachine:self->_virtualMachine restoreImageURL:restoreImageFileURL];  // macOS 설치 도구 생성

    NSLog(@"설치를 시작합니다.");  // 설치 시작 로그
    [installer installWithCompletionHandler:^(NSError *error) {  // 설치 완료 핸들러
        if (error) {  // 에러 발생 시
            abortWithErrorMessage([NSString stringWithFormat:@"%@", error.localizedDescription]);  // 에러 메시지와 함께 프로그램 종료
        } else {  // 성공 시
            NSLog(@"설치가 성공했습니다.");  // 성공 로그
        }
    }];

    [installer.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];  // 진행률 관찰자 추가
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context  // 키 값 관찰 메서드
{
    if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {  // 진행률 키 경로인 경우
        NSProgress *progress = (NSProgress *)object;  // 진행률 객체
        NSLog(@"설치 진행률: %f.", progress.fractionCompleted * 100);  // 진행률 로그

        if (progress.finished) {  // 완료된 경우
            [progress removeObserver:self forKeyPath:@"fractionCompleted"];  // 관찰자 제거
        }
    }
}

// MARK: - 공개 메서드들

// 설치 과정에서 생성되는 아티팩트를 저장하기 위해 사용자의 홈 디렉토리에 번들을 생성합니다.
- (void)setUpVirtualMachineArtifacts  // 가상머신 아티팩트 설정 메서드
{
    createVMBundle();  // VM 번들 생성 함수 호출
}

// MARK: macOS 설치 시작

- (void)installMacOS:(NSURL *)ipswURL  // macOS 설치 메서드 (IPSW 파일 URL을 받음)
{
    NSLog(@"IPSW 파일에서 설치를 시도합니다: %s\n", [ipswURL fileSystemRepresentation]);  // 설치 시도 로그
    [VZMacOSRestoreImage loadFileURL:ipswURL completionHandler:^(VZMacOSRestoreImage *restoreImage, NSError *error) {  // 복원 이미지 로드 완료 핸들러
        if (error) {  // 에러 발생 시
            abortWithErrorMessage(error.localizedDescription);  // 에러 메시지와 함께 프로그램 종료
        }

        VZMacOSConfigurationRequirements *macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration;  // 가장 기능이 풍부한 지원 설정 가져오기
        if (!macOSConfiguration || !macOSConfiguration.hardwareModel.supported) {  // 지원되는 Mac 설정이 없는 경우
            abortWithErrorMessage(@"지원되는 Mac 설정이 없습니다.");  // 에러 메시지와 함께 프로그램 종료
        }

        dispatch_async(dispatch_get_main_queue(), ^{  // 메인 큐에서 비동기 실행
            [self setupVirtualMachineWithMacOSConfigurationRequirements:macOSConfiguration];  // 가상머신 설정
            [self startInstallationWithRestoreImageFileURL:ipswURL];  // 설치 시작
        });
    }];
}

@end  // 구현 종료

#endif  // Apple Silicon 조건부 컴파일 종료
