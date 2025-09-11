# hyfervisor - macOS 가상머신 설치 도구 Makefile
# 이 Makefile은 hyfervisor macOS 가상머신 설치 도구를 빌드합니다.

# Xcode 프로젝트 설정
PROJECT = hyfervisor.xcodeproj
SCHEME = hyfervisor-InstallationTool-Objective-C
CONFIGURATION = Release
DESTINATION = generic/platform=macOS
DERIVED_DATA_PATH = build
RESULT_BUNDLE_PATH = build/Result_$(shell date +%Y%m%d-%H%M%S).xcresult

# 설치 도구 타겟
INSTALLATION_TOOL_TARGET = hyfervisor-InstallationTool-Objective-C

# 샘플 앱 타겟
APP_TARGET = hyfervisor-Objective-C

# 기본 타겟
all: $(INSTALLATION_TOOL_TARGET) $(APP_TARGET)

# 설치 도구 빌드 (xcodebuild 사용)
$(INSTALLATION_TOOL_TARGET):
	@echo "hyfervisor 설치 도구를 빌드합니다..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-resultBundlePath "$(RESULT_BUNDLE_PATH)" \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO
	@echo "빌드 완료: $(INSTALLATION_TOOL_TARGET)"
	@echo "실행 파일 위치: $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(INSTALLATION_TOOL_TARGET)"

# hyfervisor 앱 빌드 (xcodebuild 사용)
$(APP_TARGET):
	@echo "hyfervisor 앱을 빌드합니다..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(APP_TARGET) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-resultBundlePath "$(RESULT_BUNDLE_PATH)" \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO
	@echo "빌드 완료: $(APP_TARGET)"
	@echo "앱 위치: $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(APP_TARGET).app"

# 정리
clean:
	@echo "hyfervisor 빌드 파일들을 정리합니다..."
	rm -rf $(DERIVED_DATA_PATH)
	rm -f $(INSTALLATION_TOOL_TARGET)
	rm -rf $(APP_TARGET).app
	@echo "정리 완료"

# 설치 (선택사항)
install: $(INSTALLATION_TOOL_TARGET)
	@echo "hyfervisor 설치 도구를 /usr/local/bin에 설치합니다..."
	cp $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(INSTALLATION_TOOL_TARGET) /usr/local/bin/
	@echo "설치 완료"

# 제거 (선택사항)
uninstall:
	@echo "hyfervisor 설치 도구를 제거합니다..."
	rm -f /usr/local/bin/$(INSTALLATION_TOOL_TARGET)
	@echo "제거 완료"

# 도움말
help:
	@echo "hyfervisor - macOS 가상머신 도구"
	@echo ""
	@echo "사용 가능한 타겟들:"
	@echo "  all                               - 모든 타겟을 빌드합니다 (기본값)"
	@echo "  $(INSTALLATION_TOOL_TARGET)       - 설치 도구만 빌드합니다"
	@echo "  $(APP_TARGET)                     - hyfervisor 앱만 빌드합니다"
	@echo "  clean                             - 빌드 파일들을 정리합니다"
	@echo "  install                           - 설치 도구를 /usr/local/bin에 설치합니다"
	@echo "  uninstall                         - 설치 도구를 제거합니다"
	@echo "  help                              - 이 도움말을 표시합니다"
	@echo "  check-deps                        - 필요한 의존성을 확인합니다"
	@echo "  info                              - 프로젝트 정보를 표시합니다"
	@echo "  test-build                        - 빌드 테스트를 실행합니다"

# 의존성 확인
check-deps:
	@echo "hyfervisor 빌드에 필요한 의존성을 확인합니다..."
	@which xcodebuild > /dev/null || (echo "xcodebuild가 설치되지 않았습니다. Xcode를 설치하세요." && exit 1)
	@echo "xcodebuild: OK"
	@if [ ! -d $(PROJECT) ]; then \
		echo "프로젝트 파일을 찾을 수 없습니다: $(PROJECT)"; \
		exit 1; \
	fi
	@echo "프로젝트 파일: OK"
	@echo "모든 의존성이 충족되었습니다."

# 프로젝트 정보
info:
	@echo "hyfervisor 프로젝트 정보:"
	@echo "  이름: hyfervisor - macOS 가상머신 도구"
	@echo "  설명: Apple Silicon Mac에서 macOS 가상머신을 실행하는 도구"
	@echo "  언어: Objective-C"
	@echo "  플랫폼: Apple Silicon Mac (ARM64)"
	@echo "  프레임워크: Foundation, Virtualization"
	@echo "  프로젝트: $(PROJECT)"
	@echo "  설치 도구 스킴: $(SCHEME)"
	@echo "  앱 스킴: $(APP_TARGET)"
	@echo "  타겟들: $(INSTALLATION_TOOL_TARGET), $(APP_TARGET)"

# 빌드 테스트
test-build: clean $(INSTALLATION_TOOL_TARGET) $(APP_TARGET)
	@echo "hyfervisor 빌드 테스트를 실행합니다..."
	@if [ -f $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(INSTALLATION_TOOL_TARGET) ]; then \
		echo "빌드 성공: $(INSTALLATION_TOOL_TARGET)"; \
		ls -la $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(INSTALLATION_TOOL_TARGET); \
	else \
		echo "빌드 실패: $(INSTALLATION_TOOL_TARGET)"; \
		exit 1; \
	fi
	@if [ -d $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(APP_TARGET).app ]; then \
		echo "빌드 성공: $(APP_TARGET)"; \
		ls -la $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(APP_TARGET).app; \
	else \
		echo "빌드 실패: $(APP_TARGET)"; \
		exit 1; \
	fi

# 가짜 타겟들
.PHONY: all clean install uninstall help check-deps info test-build $(INSTALLATION_TOOL_TARGET) $(APP_TARGET)