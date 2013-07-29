Pod::Spec.new do |s|
  s.name    = "PodTest"
  s.version = "1.0"
  s.source  = { :http => "./PodTest.zip" }

  s.subspec "subspec_1" do |ss|
    ss.source_files = "subspec_1.{h,m}"
  end

  s.subspec "subspec_2" do |ss|
    ss.source_files = "subspec_2.{h,m}"
  end
end
