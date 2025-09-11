/*
LICENSE.txt 파일을 참조하세요.

요약:
macOS 가상머신 설치를 위한 헬퍼 클래스입니다.
*/

#ifndef HyfervisorInstaller_h  // 헤더 가드 시작
#define HyfervisorInstaller_h  // 헤더 가드 정의

#import <Foundation/Foundation.h>  // Foundation 프레임워크 임포트

#ifdef __arm64__  // Apple Silicon Mac에서만 컴파일

@interface HyfervisorInstaller : NSObject  // hyfervisor 설치 클래스 선언

- (void)setUpVirtualMachineArtifacts;  // 가상머신 아티팩트 설정 메서드

- (void)installMacOS:(NSURL *)ipswURL;  // macOS 설치 메서드 (IPSW 파일 URL을 받음)

@end  // 인터페이스 종료

#endif /* __arm64__ */  // Apple Silicon 조건부 컴파일 종료
#endif /* HyfervisorInstaller_h */  // 헤더 가드 종료
