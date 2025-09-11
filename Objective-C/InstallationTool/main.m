/*
LICENSE.txt 파일을 참조하세요.

요약:
macOS 가상머신 설치 도구의 진입점입니다.
*/

#import "Error.h"  // 에러 처리 헬퍼 함수들
#import "HyfervisorInstaller.h"  // hyfervisor 설치 클래스
#import "Path.h"  // 경로 관련 헬퍼 함수들

#import <Foundation/Foundation.h>  // Foundation 프레임워크

int main(int argc, const char * argv[])
{
#ifdef __arm64__  // Apple Silicon Mac에서만 실행
    @autoreleasepool {  // 자동 메모리 관리 풀
        HyfervisorInstaller *installer = [HyfervisorInstaller new];  // 설치 도구 인스턴스 생성

        if (argc == 2) {  // IPSW 파일 경로가 인자로 제공된 경우
            NSString *ipswPath = [NSString stringWithUTF8String:argv[1]];  // 첫 번째 인자를 NSString으로 변환

            NSURL *ipswURL = [[NSURL alloc] initFileURLWithPath:ipswPath];  // 파일 URL 생성
            if (!ipswURL.isFileURL) {  // 유효한 파일 URL인지 확인
                abortWithErrorMessage(@"제공된 IPSW 경로가 유효한 파일 URL이 아닙니다.");  // 에러 메시지와 함께 프로그램 종료
            }

            [installer setUpVirtualMachineArtifacts];  // 가상머신 아티팩트 설정
            [installer installMacOS:ipswURL];  // macOS 설치 시작

            dispatch_main();  // 메인 디스패치 큐 실행
        } else {  // 인자가 잘못된 경우
            NSLog(@"잘못된 인자입니다. IPSW 파일의 경로를 제공해주세요.");  // 에러 메시지 출력
            NSLog(@"사용법: %s <IPSW파일경로>", argv[0]);  // 사용법 안내
            exit(-1);  // 프로그램 종료
        }
    }
#else
    NSLog(@"이 도구는 Apple Silicon Mac에서만 실행할 수 있습니다.");  // 에러 메시지 출력
    exit(-1);  // 프로그램 종료
#endif
}
