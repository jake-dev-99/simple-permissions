Pod::Spec.new do |s|
  s.name             = 'simple_permissions_macos'
  s.version          = '1.3.0'
  s.summary          = 'macOS implementation for simple_permissions federated plugin.'
  s.description      = <<-DESC
macOS implementation for simple_permissions federated plugin.
                       DESC
  s.homepage         = 'https://github.com/simplezen/simple-permissions'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SimpleZen' => 'support@simplezen.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resource_bundles  = { 'simple_permissions_macos_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'

  s.frameworks = 'AVFoundation', 'Contacts', 'CoreLocation',
                 'EventKit', 'Photos', 'AppKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.swift_version = '5.0'
end
