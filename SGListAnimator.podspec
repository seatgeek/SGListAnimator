Pod::Spec.new do |s|
  s.name         = 'SGListAnimator'
  s.version      = '1.0.0'
  s.summary      = "Animated transitions for your table and collection views"
  s.description = %{
    SGListAnimator provides animated transitions for your table and collection
    views, so you don't have to resort to calling `reloadData`, which blinks
    your UI over to the new state with no animation.
  }
  s.homepage     = 'https://github.com/seatgeek/SGListAnimator'
  s.license      = { :type => 'BSD', :file => 'LICENSE' }
  s.author       = 'SeatGeek'
  s.ios.deployment_target = '7.0'
  s.source       = { :git => 'https://github.com/seatgeek/SGListAnimator.git', :tag => s.version }
  s.source_files = 'SGListAnimator/*.{h,m}'
  s.requires_arc = true
  s.ios.frameworks = 'Foundation', 'UIKit'
end
