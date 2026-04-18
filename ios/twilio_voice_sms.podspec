#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint twilio_voice_sms.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'twilio_voice_sms'
  s.version          = '0.1.0'
  s.summary          = 'Twilio Programmable Voice + REST SMS for Flutter.'
  s.description      = <<-DESC
  Voice (CallKit + PushKit) + SMS (REST) for iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/minhtri1401/twilio_voice_sms'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MinhTri1401' => 'minhtri1412000@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'TwilioVoice', '~> 6.13.6'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version           = '5.0'
  s.ios.deployment_target   = '13.0'
end
