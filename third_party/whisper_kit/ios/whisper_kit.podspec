Pod::Spec.new do |s|
  s.name             = 'whisper_kit'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for offline speech-to-text using whisper.cpp with enhanced audio support.'
  s.description      = <<-DESC
A Flutter plugin for offline speech-to-text using whisper.cpp models implementation with full iOS support, real-time streaming transcription, multi-format audio conversion, and advanced audio preprocessing.
                       DESC
  s.homepage         = 'https://github.com/CodeSagePath/whisper_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CodeSagePath' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = [
    'Classes/WhisperKitPlugin.swift',
    'Classes/WhisperKitPlugin.h',
    'Classes/AudioRecorder.swift',
    'Classes/PermissionManager.swift',
    'Classes/ModelManager.swift',
    'src/**/*.{h,c,cpp}'
  ]
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Add C++ standard library support
  s.library = 'c++'

  # Configure for C++ files
  s.public_header_files = 'Classes/**/*.h', 'src/**/*.h'
  s.private_header_files = 'Classes/**/*.h', 'src/**/*.h'

  # Add compiler flags for C++
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => '-D__cplusplus=201703L -stdlib=libc++'
  }

  # Enhanced framework dependencies
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'Foundation', 'Accelerate'

  # Test files
  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'RunnerTests/**/*'
    test_spec.dependency 'Flutter'
  end


end