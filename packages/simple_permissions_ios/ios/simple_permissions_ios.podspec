Pod::Spec.new do |s|
  s.name             = 'simple_permissions_ios'
  s.version          = '1.3.0'
  s.summary          = 'iOS implementation for simple_permissions federated plugin.'
  s.description      = <<-DESC
iOS implementation for simple_permissions federated plugin.
                       DESC
  s.homepage         = 'https://github.com/simplezen/simple-permissions'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SimpleZen' => 'support@simplezen.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resource_bundles  = { 'simple_permissions_ios_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'

  s.frameworks = 'AVFoundation', 'Contacts', 'CoreLocation', 'CoreMotion',
                 'EventKit', 'HealthKit', 'Photos', 'UIKit',
                 'UserNotifications', 'AppTrackingTransparency'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
