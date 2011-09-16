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
        "{Classes,External/Reachability}/*.{h,m}",
        {
          "USER_HEADER_SEARCH_PATHS" => "$(BUILT_PRODUCTS_DIR)",
          "ALWAYS_SEARCH_USER_PATHS" => "YES",
          "OTHER_LDFLAGS" => "-framework SystemConfiguration -framework CFNetwork " \
                             "-framework MobileCoreServices -l z.1.2.3"
        }
      ],
      [
        'Reachability',
        ["External/Reachability/*.h", "External/Reachability/*.m"],
        "External/Reachability/*.{h,m}",
        {
          "USER_HEADER_SEARCH_PATHS" => "$(BUILT_PRODUCTS_DIR)",
          "ALWAYS_SEARCH_USER_PATHS" => "YES"
        }
      ],
      [
        'ASIWebPageRequest',
        ['**/ASIWebPageRequest.*'],
        "{Classes,Classes/ASIWebPageRequest,External/Reachability}/*.{h,m}",
        {
          "USER_HEADER_SEARCH_PATHS" => "$(BUILT_PRODUCTS_DIR)",
          "ALWAYS_SEARCH_USER_PATHS" => "YES",
          "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2",
          "OTHER_LDFLAGS" => "-l xml2.2.7.3 -framework SystemConfiguration " \
                             "-framework CFNetwork -framework MobileCoreServices -l z.1.2.3"
        }
      ],
    ].each do |name, patterns, expected_pattern, xcconfig|
      Pod::Source.reset!
      Pod::Spec::Set.reset!
      installer = Pod::Installer.new(Pod::Spec.new { dependency(name); source_files(*patterns) })
      expected  = (stubbed_destroot(installer) + expected_pattern).glob.map do |file|
        file.relative_path_from(config.project_pods_root)
      end
      installer.generate_project
      installer.source_files.size.should == expected.size
      installer.source_files.sort.should == expected.sort
      installer.xcodeproj.source_files.size.should == expected.size
      installer.xcodeproj.source_files.sort.should == expected.sort
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
