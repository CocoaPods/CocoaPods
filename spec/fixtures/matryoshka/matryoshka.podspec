Pod::Spec.new do |s|
  s.name             = "matryoshka"
  s.version          = "1.0.0"
  s.author           = { "Matryona Malyutin" => "matryona@malyutin.local" }
  s.summary          = "👩‍👩‍👧"
  s.description      = "Four levels: outmost (root), outer, inner"
  s.homepage         = "http://httpbin.org/html"
  s.source           = { :git => "http://malyutin.local/matryoshka.git", :tag => s.version.to_s }
  s.license          = 'MIT'

  s.source_files = 'Outmost.{h,m}'

  s.default_subspecs = 'Outer'

  s.subspec 'Outer' do |outer_subspec|
    outer_subspec.source_files = 'Outer/Outer.{h,m}'

    outer_subspec.subspec 'Inner' do |inner_subspec|
      inner_subspec.source_files = 'Inner/Inner.{h,m}'
    end
  end

  s.subspec 'Foo' do |ss|
    ss.source_files = 'Foo/Foo.{h,m}'
  end

  s.subspec 'Bar' do |ss|
    ss.source_files = 'Bar/Bar.{h,m}'
  end
end
