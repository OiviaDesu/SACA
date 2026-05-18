"""Check that meaningful SACA folders have README files.

This is a documentation audit only. It intentionally ignores generated,
cache, resource-density, IDE, and vendor-noise folders.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


REQUIRED_DIRS = {
    ".github",
    ".github/ISSUE_TEMPLATE",
    ".github/workflows",
    ".githooks",
    "android",
    "android/app",
    "android/app/src",
    "android/app/src/main",
    "android/app/src/main/kotlin/com/saca/app",
    "android/app/src/main/res",
    "android/gradle",
    "assets",
    "assets/branding",
    "assets/data",
    "assets/images",
    "assets/models",
    "assets/models/classifier-xgb-best",
    "assets/models/classifier-xgb-quick",
    "assets/models/saca-hybrid-logreg-v1",
    "assets/models/sherpa-onnx-whisper-base",
    "assets/models/sherpa-onnx-whisper-gue-base-run4-rc1",
    "assets/models/whisper-gue-base-run4-rc1",
    "docs",
    "ios",
    "ios/Flutter",
    "ios/Runner",
    "ios/Runner.xcodeproj",
    "ios/Runner.xcworkspace",
    "ios/RunnerTests",
    "lib",
    "lib/application",
    "lib/application/assessment",
    "lib/core",
    "lib/core/errors",
    "lib/core/layout",
    "lib/core/runtime",
    "lib/core/theme",
    "lib/domain",
    "lib/domain/models",
    "lib/domain/services",
    "lib/infrastructure",
    "lib/infrastructure/analysis",
    "lib/infrastructure/analysis/generated_local",
    "lib/infrastructure/app",
    "lib/infrastructure/localization",
    "lib/infrastructure/platform",
    "lib/infrastructure/speech",
    "lib/infrastructure/speech/whisper_service_parts",
    "lib/infrastructure/web",
    "lib/infrastructure/window",
    "lib/presentation",
    "lib/presentation/adaptive",
    "lib/presentation/controllers",
    "lib/presentation/localization",
    "lib/presentation/readiness",
    "lib/presentation/screens",
    "lib/presentation/screens/saca_flow",
    "lib/presentation/settings",
    "lib/presentation/widgets",
    "lib/presentation/widgets/saca_controls",
    "macos",
    "macos/Flutter",
    "macos/Runner",
    "macos/Runner.xcodeproj",
    "macos/Runner.xcworkspace",
    "macos/Runner/Configs",
    "macos/RunnerTests",
    "python_pipeline",
    "python_pipeline/analysis",
    "python_pipeline/data",
    "python_pipeline/data/processed",
    "python_pipeline/data/raw",
    "python_pipeline/data/samples",
    "python_pipeline/data_ingestion",
    "python_pipeline/docs",
    "python_pipeline/export",
    "python_pipeline/hpc",
    "python_pipeline/hpc/legacy_wrappers",
    "python_pipeline/requirements",
    "python_pipeline/scripts",
    "python_pipeline/scripts/legacy_wrappers",
    "python_pipeline/tests",
    "python_pipeline/training",
    "test",
    "third_party",
    "third_party/whisper_kit",
    "tools",
    "web",
    "web/icons",
    "windows",
    "windows/flutter",
    "windows/runner",
}


def tracked_files() -> set[str]:
    output = subprocess.check_output(["git", "ls-files"], text=True)
    return {line.strip().replace("\\", "/") for line in output.splitlines() if line.strip()}


def main() -> int:
    files = tracked_files()
    missing = []

    for folder in sorted(REQUIRED_DIRS):
        readme = f"{folder}/README.md"
        if readme not in files and not Path(readme).is_file():
            missing.append(readme)

    if missing:
        print("Missing README files for meaningful folders:")
        for path in missing:
            print(f"- {path}")
        return 1

    print(f"README coverage OK for {len(REQUIRED_DIRS)} meaningful folders.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
