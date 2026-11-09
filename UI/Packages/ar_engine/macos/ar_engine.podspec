Pod::Spec.new do |s|
  s.name             = 'ar_engine'
  s.version          = '0.4.0'
  s.summary          = 'Multi-platform AR engine plugin for Flutter on macOS.'
  s.description      = <<-DESC
    Augmented Reality plugin backed by webcam capture and synthetic
    visual-odometry-compatible scene events on macOS.
  DESC
  s.homepage         = 'https://github.com/yourorg/ar_engine'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Org' => 'ar@yourorg.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.swift_version    = '5.9'
  s.frameworks       = 'Cocoa', 'AVFoundation', 'Metal', 'MetalKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
