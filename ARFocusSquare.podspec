#
# Be sure to run `pod lib lint ARFocusSquare.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ARFocusSquare'
  s.version          = '4.0.0'
  s.summary          = 'A reusable version of FocusSquare from Apple example.'

  s.description      = <<-DESC
FocusNode shows the estimation of vertical or horizontal planes,
with a node being placed at that location with the correct orientation.
This class is only an adaptation of Apple's sample code found at this location:
https://developer.apple.com/documentation/arkit/handling_3d_interaction_and_ui_controls_in_augmented_reality
It requires iOS 13.0 or higher and was tested with Swift 5.1
                       DESC

  s.homepage         = 'https://github.com/ifullgaz/ARFocusSquare'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Emmanuel Merali' => 'emmanuel@merali.me' }
  s.module_name      = 'ARFocusSquare'
  s.source           = { :git => 'https://github.com/ifullgaz/ARFocusSquare.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_versions        = ['5.0', '5.1']

  s.source_files = 'ARFocusSquare/Classes/**/*'
  s.dependency     'IFGExtensions'
end
