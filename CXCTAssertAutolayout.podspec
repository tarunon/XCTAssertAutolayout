Pod::Spec.new do |s|
  s.name             = 'CXCTAssertAutolayout'
  s.version          = '0.3.0'
  s.summary          = 'Provides assert function that check memory leak in Swift.'
  s.description      = <<-DESC
Provides memory leak test cases for Swift.
Found memory leak objects from traverse object tree using Mirror.

                       DESC
  s.homepage         = 'https://github.com/tarunon/XCTAssertAutolayout'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tarunon' => 'croissant9603@gmail.com' }
  s.source           = { :git => 'https://github.com/tarunon/XCTAssertAutolayout.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.source_files = 'Sources/CXCTAssertAutolayout/**/*'
  s.framework = 'UIKit'
end
