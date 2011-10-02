require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer" do
  before do
    config.project_pods_root = fixture('integration')
    fixture('spec-repos/master') # ensure the archive is unpacked
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.project_pods_root = nil
    config.repos_dir = SpecHelper.tmp_repos_path
  end

  it "adds all source files that should be included in the library to the xcode project" do
    [
      [
        'ASIHTTPRequest',
        ['Classes'],
        { 'ASIHTTPRequest' => "Classes/*.{h,m}", 'Reachability' => "External/Reachability/*.{h,m}" },
        {
          "USER_HEADER_SEARCH_PATHS" => '"$(BUILT_PRODUCTS_DIR)/Pods" ' \
                                        '"$(BUILT_PRODUCTS_DIR)/Pods/ASIHTTPRequest" ' \
                                        '"$(BUILT_PRODUCTS_DIR)/Pods/Reachability"',
          "ALWAYS_SEARCH_USER_PATHS" => "YES",
          "OTHER_LDFLAGS" => "-framework SystemConfiguration -framework CFNetwork " \
                             "-framework MobileCoreServices -l z.1"
        }
      ],
      [
        'Reachability',
        ["External/Reachability/*.h", "External/Reachability/*.m"],
        { 'Reachability' => "External/Reachability/*.{h,m}", },
        {
          "USER_HEADER_SEARCH_PATHS" => '"$(BUILT_PRODUCTS_DIR)/Pods" ' \
                                        '"$(BUILT_PRODUCTS_DIR)/Pods/Reachability"',
          "ALWAYS_SEARCH_USER_PATHS" => "YES"
        }
      ],
      [
        'ASIWebPageRequest',
        ['**/ASIWebPageRequest.*'],
        { 'ASIHTTPRequest' => "Classes/*.{h,m}", 'ASIWebPageRequest' => "Classes/ASIWebPageRequest/*.{h,m}", 'Reachability' => "External/Reachability/*.{h,m}" },
        {
          "USER_HEADER_SEARCH_PATHS" => '"$(BUILT_PRODUCTS_DIR)/Pods" ' \
                                        '"$(BUILT_PRODUCTS_DIR)/Pods/ASIHTTPRequest" ' \
                                        '"$(BUILT_PRODUCTS_DIR)/Pods/Reachability"',
          "ALWAYS_SEARCH_USER_PATHS" => "YES",
          "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2",
          "OTHER_LDFLAGS" => "-l xml2.2.7.3 -framework SystemConfiguration " \
                             "-framework CFNetwork -framework MobileCoreServices -l z.1"
        }
      ],
    ].each do |name, patterns, expected_patterns, xcconfig|
      Pod::Source.reset!
      Pod::Spec::Set.reset!

      installer = Pod::Installer.new(Pod::Spec.new { |s| s.dependency(name); s.source_files = *patterns })
      destroot = stubbed_destroot(installer)
      installer.generate_project

      expected_patterns.each do |name, pattern|
        expected = (destroot + pattern).glob.map do |file|
          file.relative_path_from(config.project_pods_root)
        end
        installer.source_files[name].size.should == expected.size
        installer.source_files[name].sort.should == expected.sort
        installer.xcodeproj.source_files[name].size.should == expected.size
        installer.xcodeproj.source_files[name].sort.should == expected.sort
      end
      installer.xcconfig.to_hash.should == xcconfig
    end
  end

  def stubbed_destroot(installer)
    set = installer.dependent_specification_sets.find { |s| s.name == 'ASIHTTPRequest' }
    spec = set.specification
    set.extend(Module.new { define_method(:specification) { spec }})
    def spec.pod_destroot
      config.project_pods_root + 'ASIHTTPRequest' # without name and version
    end
    spec.pod_destroot
  end
end
