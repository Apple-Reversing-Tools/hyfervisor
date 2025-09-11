# hyfervisor - Apple Silicon Mac에서 macOS 가상머신 실행 도구

## 개요

hyfervisor는 Apple Silicon Mac에서 macOS 가상머신을 실행할 수 있는 도구입니다. 이 프로젝트는 Apple의 Virtualization 프레임워크를 사용하여 네이티브 macOS 가상화 환경을 제공합니다.

## 주요 기능

- **macOS 가상머신 실행**: Apple Silicon Mac에서 macOS를 가상머신으로 실행
- **하드웨어 가상화**: CPU, 메모리, 그래픽, 네트워크, 오디오 등 다양한 하드웨어 구성 지원
- **디버그 지원**: GDB 디버그 스텁을 통한 가상머신 디버깅 기능
- **GUI 애플리케이션**: 사용자 친화적인 그래픽 인터페이스

## 시스템 요구사항

- **하드웨어**: Apple Silicon Mac (M1, M2, M3 등)
- **운영체제**: macOS 12.0 (Monterey) 이상

## 프로젝트 구조

```
hyfervisor/
├── Objective-C/                    # Objective-C 구현 파일들
│   ├── Common/                     # 공통 헬퍼 클래스들
│   │   ├── HyfervisorConfigurationHelper.h/m  # 가상머신 구성 헬퍼
│   │   ├── HyfervisorDelegate.h/m             # 가상머신 델리게이트
│   │   ├── Error.h                            # 에러 정의
│   │   └── Path.h                             # 경로 유틸리티
│   ├── InstallationTool/           # 설치 도구
│   │   ├── HyfervisorInstaller.h/m           # 설치 도구 구현
│   │   └── main.m                            # 설치 도구 메인
│   └── hyfervisor/                 # 메인 애플리케이션
│       └── AppDelegate.m                     # 앱 델리게이트
├── Configuration/                   # Xcode 설정 파일들
│   └── SampleCode.xcconfig
├── hyfervisor.xcodeproj/           # Xcode 프로젝트 파일
├── hyfervisor.entitlements         # 앱 권한 설정
├── InstallationTool.entitlements  # 설치 도구 권한 설정
├── Makefile                        # 빌드 자동화 스크립트
└── 15_6.ipsw                       # macOS 설치 이미지 파일
```

## 빌드 및 실행

### 1. 의존성 확인
```bash
make check-deps
```

### 2. 전체 빌드
```bash
make all
```

### 3. 설치 도구만 빌드
```bash
make hyfervisor-InstallationTool-Objective-C
```

### 4. 앱만 빌드
```bash
make hyfervisor-Objective-C
```

### 5. 빌드 정리
```bash
make clean
```

## 사용 방법

### 1. 설치 도구 실행
```bash
# 빌드 후 실행 파일 위치
./build/Build/Products/Release/hyfervisor-InstallationTool-Objective-C
```

### 2. 메인 애플리케이션 실행
```bash
# 빌드 후 앱 실행
open build/Build/Products/Release/hyfervisor-Objective-C.app
```

## 주요 구성 요소

### HyfervisorConfigurationHelper
- 가상머신의 하드웨어 구성을 생성하는 헬퍼 클래스
- CPU, 메모리, 그래픽, 네트워크, 오디오 장치 설정
- 부트로더 및 블록 장치 구성

### HyfervisorInstaller
- macOS 설치를 담당하는 설치 도구
- IPSW 파일을 사용한 macOS 설치 프로세스 관리

### AppDelegate
- 메인 애플리케이션의 핵심 로직
- 가상머신 생성, 시작, 중지 기능
- 디버그 및 복구 모드 지원

## 디버그 기능

- **GDB 디버그 스텁**: 가상머신 내부 디버깅 지원
- **콘솔 모드**: 텍스트 기반 콘솔 접근
- **패닉 장치**: 커널 패닉 디버깅 지원

## 네트워크 설정

- **Virtio 네트워크**: 고성능 가상 네트워크 장치
- **인터페이스 선택**: 다양한 네트워크 인터페이스 지원



## 문제 해결

### 빌드 오류
```bash
# 의존성 확인
make check-deps

# 정리 후 재빌드
make clean
make all
```

