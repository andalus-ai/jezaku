Pod::Spec.new do |s|
  s.name             = 'ar_engine'
  s.version          = '0.1.0'
  s.summary          = 'Multi-platform AR engine plugin for Flutter using ARKit on iOS.'
  s.description      = <<-DESC
    Augmented Reality plugin backed by ARKit on iOS, ARCore on Android,
    WebXR on Web, and a Metal/OpenGL fallback on macOS/Desktop.
  DESC
  s.homepage         = 'https://github.com/yourorg/ar_engine'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Org' => 'ar@yourorg.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'   # ARKit world tracking requires iOS 11+; 14 for raycast API
  s.swift_version    = '5.9'
  s.frameworks       = 'ARKit', 'SceneKit', 'Metal', 'MetalKit', 'CoreMotion', 'AVFoundation'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
