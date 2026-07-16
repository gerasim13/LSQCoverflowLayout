Pod::Spec.new do |s|
  s.name             = 'LSQCoverflowLayout'
  s.version          = '0.2.0'
  s.summary          = 'A reusable UIKit coverflow with two-sided, flippable covers.'
  s.description      = <<-DESC
    LSQCoverflowLayout preserves Loopseque's spline-driven UICollectionView
    coverflow and adds a reusable view wrapper for lazy two-sided covers.
  DESC
  s.homepage         = 'https://github.com/gerasim13/LSQCoverflowLayout'
  s.license          = { :type => 'MIT and BSD-3-Clause', :file => 'LICENSES.md' }
  s.author           = { 'Pavel Litvinenko' => 'gerasim13@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/gerasim13/LSQCoverflowLayout.git', :tag => s.version.to_s }

  # Xcode 26 no longer ships libarclite for deployment targets below iOS 12.
  s.platform         = :ios, '12.0'
  s.requires_arc     = true
  s.frameworks       = 'UIKit', 'QuartzCore', 'CoreFoundation'
  s.libraries        = 'c++'
  s.source_files     = 'LSQCoverflowLayout/*.{h,m,cpp}',
                       'Libraries/BSpline/BSpline/*.{h,cpp}'
  s.public_header_files = 'LSQCoverflowLayout/LSQCoverflowLayout.h',
                          'LSQCoverflowLayout/LSQCoverflowCellView.h',
                          'LSQCoverflowLayout/LSQCoverflowView.h'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++11',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Libraries/BSpline/BSpline"'
  }
end
