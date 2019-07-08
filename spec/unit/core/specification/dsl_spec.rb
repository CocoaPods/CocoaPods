require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Specification::DSL do
    describe 'Root specification attributes' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
        end
      end

      it 'allows to specify the name' do
        @spec.name = 'Name'
        @spec.attributes_hash['name'].should == 'Name'
      end

      it 'allows to specify the version' do
        @spec.version = '1.0'
        @spec.attributes_hash['version'].should == '1.0'
      end

      it 'allows specifying the swift version in singular form' do
        @spec.swift_version = '3.0'
        @spec.attributes_hash['swift_versions'].should == '3.0'
      end

      it 'allows specifying multiple swift versions in singular form' do
        @spec.swift_version = '3.0', '4.0'
        @spec.attributes_hash['swift_versions'].should == ['3.0', '4.0']
      end

      it 'allows specifying multiple swift versions as an array in singular form' do
        @spec.swift_version = ['3.0', '4.0']
        @spec.attributes_hash['swift_versions'].should == ['3.0', '4.0']
      end

      it 'allows specifying the swift version in plural form' do
        @spec.swift_versions = '3.0'
        @spec.attributes_hash['swift_versions'].should == '3.0'
      end

      it 'allows specifying multiple swift versions in plural form' do
        @spec.swift_versions = '3.0', '4.0'
        @spec.attributes_hash['swift_versions'].should == ['3.0', '4.0']
      end

      it 'allows specifying multiple swift versions as an array in plural form' do
        @spec.swift_versions = ['3.0', '4.0']
        @spec.attributes_hash['swift_versions'].should == ['3.0', '4.0']
      end

      it 'allows specifying the cocoapods version' do
        @spec.cocoapods_version = '>= 0.36'
        @spec.attributes_hash['cocoapods_version'].should == '>= 0.36'
      end

      it 'allows to specify the authors' do
        hash = { 'Darth Vader' => 'darthvader@darkside.com',
                 'Wookiee' => 'wookiee@aggrrttaaggrrt.com' }
        @spec.authors = hash
        @spec.attributes_hash['authors'].should == hash
      end

      it 'allows to specify the authors in the singular form' do
        @spec.author = { 'orta' => 'orta.therox@gmail.com' }
        @spec.attributes_hash['authors'].should == { 'orta' => 'orta.therox@gmail.com' }
      end

      it 'allows to specify the social media contact' do
        @spec.social_media_url = 'https://twitter.com/cocoapods'
        @spec.attributes_hash['social_media_url'].should == 'https://twitter.com/cocoapods'
      end

      it 'allows to specify the license' do
        @spec.license = { :type => 'MIT', :file => 'MIT-LICENSE' }
        @spec.attributes_hash['license'].should == { 'type' => 'MIT', 'file' => 'MIT-LICENSE' }
      end

      it 'allows to specify the homepage' do
        @spec.homepage = 'www.example.com'
        @spec.attributes_hash['homepage'].should == 'www.example.com'
      end

      it 'allows to specify the source' do
        @spec.source = { :git => 'www.example.com/repo.git' }
        @spec.attributes_hash['source'].should == { 'git' => 'www.example.com/repo.git' }
      end

      it 'allows to specify the summary' do
        @spec.summary = 'text'
        @spec.attributes_hash['summary'].should == 'text'
      end

      it 'allows to specify the description' do
        @spec.description = 'text'
        @spec.attributes_hash['description'].should == 'text'
      end

      it 'allows to specify the documentation URL' do
        @spec.documentation_url = 'www.example.com'
        @spec.attributes_hash['documentation_url'].should == 'www.example.com'
      end

      it 'allows to specify a prepare command' do
        @spec.prepare_command = 'ruby build_files.rb'
        @spec.attributes_hash['prepare_command'].should == 'ruby build_files.rb'
      end

      it 'allows to specify whether the Pod has a static_framework' do
        @spec.static_framework = true
        @spec.attributes_hash['static_framework'].should == true
      end

      it 'allows to specify whether the Pod has been deprecated' do
        @spec.deprecated = true
        @spec.attributes_hash['deprecated'].should == true
      end

      it 'allows to specify the name of the Pod that this one has been deprecated in favor of' do
        @spec.deprecated_in_favor_of = 'NewMoreAwesomePod'
        @spec.attributes_hash['deprecated_in_favor_of'].should == 'NewMoreAwesomePod'
      end

      it 'allows specifying info.plist values' do
        hash = {
          'SOME_VAR' => 'SOME_VALUE',
        }
        @spec.info_plist = hash
        @spec.attributes_hash['info_plist'].should == hash
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Platform' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
        end
      end

      it 'allows to specify the supported platform' do
        @spec.platform = :ios
        @spec.attributes_hash['platforms'].should == { 'ios' => nil }
      end

      it 'allows to specify the deployment target along the supported platform as a shortcut' do
        @spec.platform = :ios, '6.0'
        @spec.attributes_hash['platforms'].should == { 'ios' => '6.0' }
      end

      it 'allows to specify a deployment target for each platform' do
        @spec.ios.deployment_target = '6.0'
        @spec.attributes_hash['platforms']['ios'].should == '6.0'
      end

      it "doesn't allows to specify the deployment target without a platform" do
        e = lambda { @spec.deployment_target = '6.0' }.should.raise Informative
        e.message.should.match /declared only per platform/
      end

      it 'allows to specify watchOS as supported platform' do
        @spec.platform = :watchos
        @spec.attributes_hash['platforms'].should == { 'watchos' => nil }
      end

      it 'allows to specify a deployment target for the watchOS platform' do
        @spec.watchos.deployment_target = '2.0'
        @spec.attributes_hash['platforms']['watchos'].should == '2.0'
      end

      it 'allows to specify tvOS as supported platform' do
        @spec.platform = :tvos
        @spec.attributes_hash['platforms'].should == { 'tvos' => nil }
      end

      it 'allows to specify a deployment target for the tvOS platform' do
        @spec.tvos.deployment_target = '9.0'
        @spec.attributes_hash['platforms']['tvos'].should == '9.0'
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Build settings' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
        end
      end

      #------------------#

      describe 'dependency' do
        it 'allows to specify a dependencies' do
          @spec.dependencies = { 'SVStatusHUD' => ['~>1.0', '< 1.4'] }
          @spec.attributes_hash['dependencies'].should == { 'SVStatusHUD' => ['~>1.0', '< 1.4'] }
        end

        it 'allows to specify a single dependency as a shortcut' do
          @spec.dependency('SVStatusHUD', '~>1.0', '< 1.4')
          @spec.attributes_hash['dependencies'].should == { 'SVStatusHUD' => ['~>1.0', '< 1.4'] }
        end

        it 'allows to specify a single dependency as a shortcut with one version requirement' do
          @spec.dependency('SVStatusHUD', '~>1.0')
          @spec.attributes_hash['dependencies'].should == { 'SVStatusHUD' => ['~>1.0'] }
        end

        it 'allows to specify a single dependency as a shortcut with no version requirements' do
          @spec.dependency('SVStatusHUD')
          @spec.attributes_hash['dependencies'].should == { 'SVStatusHUD' => [] }
        end

        it 'allows a dependency whose name matches part of one of its parents names' do
          @spec.subspec 'subspectest' do |sp|
            sp.subspec 'subsubspec' do |ssp|
              ssp.dependency('subspec')
              ssp.attributes_hash['dependencies'].should == { 'subspec' => [] }
            end
          end
        end

        it 'raises if the specification requires itself' do
          should.raise Informative do
            @spec.dependency('Pod')
          end.message.should.match /can't require itself/
        end

        it 'raises if the specification requires one of its parents' do
          @spec.subspec 'subspec' do |_sp|
          end
          subspec = @spec.subspecs.first
          should.raise Informative do
            subspec.dependency('Pod')
          end.message.should.match /can't require one of its parents/

          # Ensure nested subspecs are prevented from requiring one of their parents
          @spec.subspec 'subspec' do |sp|
            sp.subspec 'subsubspec' do |ssp|
              should.raise Informative do
                ssp.dependency('Pod/subspec')
              end.message.should.match /can't require one of its parents/
            end
          end
        end

        it 'raises if the requirements are not supported' do
          should.raise Informative do
            @spec.dependency('SVProgressHUD', :head)
          end.message.should.match /Unsupported version requirements. \[\:head\] is not valid/
        end

        it 'raises if the requirements specify :git' do
          should.raise Informative do
            @spec.dependency('SVProgressHUD', :git => 'AnyPath')
          end.message.should.match /Podspecs cannot specify the source of dependencies. The `:git` option is not supported.\.*/
        end

        it 'raises if the requirements specify :path' do
          should.raise Informative do
            @spec.dependency('SVProgressHUD', :path => 'AnyPath')
          end.message.should.match /Podspecs cannot specify the source of dependencies. The `:path` option is not supported.\.*/
        end

        it 'raises when attempting to assign a value to dependency' do
          should.raise Informative do
            @spec.dependency = 'JSONKit', '1.5'
          end.message.should.match /Cannot assign value to `dependency`. Did you mean: `dependency 'JSONKit', '1.5'`?/
        end
      end

      #------------------#

      it 'allows to specify whether the specification requires ARC' do
        @spec.requires_arc = false
        @spec.attributes_hash['requires_arc'].should == false
      end

      it 'allows to specify which files require ARC' do
        @spec.requires_arc = ['arc/*.{h,m}']
        @spec.attributes_hash['requires_arc'].should == ['arc/*.{h,m}']

        @spec.requires_arc = 'arc/*.{h,m}'
        @spec.attributes_hash['requires_arc'].should == 'arc/*.{h,m}'
      end

      it 'allows to specify the frameworks' do
        @spec.framework = %w(QuartzCore CoreData)
        @spec.attributes_hash['frameworks'].should == %w(QuartzCore CoreData)
      end

      it 'allows to specify the weak frameworks' do
        @spec.weak_frameworks = %w(Twitter iAd)
        @spec.attributes_hash['weak_frameworks'].should == %w(Twitter iAd)
      end

      it 'allows to specify the libraries' do
        @spec.libraries = 'z', 'xml2'
        @spec.attributes_hash['libraries'].should == %w(z xml2)
      end

      it 'allows to specify compiler flags' do
        @spec.compiler_flags = %w(-Wdeprecated-implementations -Wunused-value)
        @spec.attributes_hash['compiler_flags'].should == %w(-Wdeprecated-implementations -Wunused-value)
      end

      it 'allows to specify pod target xcconfig settings' do
        @spec.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-lObjC' }
        @spec.attributes_hash['pod_target_xcconfig'].should == { 'OTHER_LDFLAGS' => '-lObjC' }
      end

      it 'allows to specify user target xcconfig settings' do
        @spec.user_target_xcconfig = { 'OTHER_CPLUSPLUSFLAGS' => '-std=c++1y' }
        @spec.attributes_hash['user_target_xcconfig'].should == { 'OTHER_CPLUSPLUSFLAGS' => '-std=c++1y' }
      end

      it 'allows to specify the contents of the prefix header' do
        @spec.prefix_header_contents = '#import <UIKit/UIKit.h>'
        @spec.attributes_hash['prefix_header_contents'].should == '#import <UIKit/UIKit.h>'
      end

      it 'allows to specify the path of compiler header file' do
        @spec.prefix_header_file = 'iphone/include/prefix.pch'
        @spec.attributes_hash['prefix_header_file'].should == 'iphone/include/prefix.pch'
      end

      it 'allows to skip prefix header file generation' do
        @spec.prefix_header_file = false
        @spec.attributes_hash['prefix_header_file'].should == false
      end

      it 'allows to specify a directory to use for the headers' do
        @spec.header_dir = 'Three20Core'
        @spec.attributes_hash['header_dir'].should == 'Three20Core'
      end

      it 'allows to specify a directory to preserver the namespacing of the headers' do
        @spec.header_mappings_dir = 'src/include'
        @spec.attributes_hash['header_mappings_dir'].should == 'src/include'
      end

      it 'allows to specify a custom module name' do
        @spec.module_name = 'Three20'
        @spec.attributes_hash['module_name'].should == 'Three20'
      end

      it 'allows to specify a custom module map file' do
        @spec.module_map = 'module.modulemap'
        @spec.attributes_hash['module_map'].should == 'module.modulemap'
      end

      it 'allows to specify the script phases shipped with the Pod' do
        @spec.script_phases = { :name => 'Hello World', :script => 'echo "Hello World"' }
        @spec.attributes_hash['script_phases'].should == { 'name' => 'Hello World', 'script' => 'echo "Hello World"' }
      end

      it 'allows to specify the script phases shipped with the Pod as a hash' do
        @spec.script_phases = { :name => 'Hello Ruby World', :script => 'puts "Hello Ruby World"', :shell_path => 'usr/bin/ruby' }
        @spec.attributes_hash['script_phases'].should == { 'name' => 'Hello Ruby World', 'script' => 'puts "Hello Ruby World"', 'shell_path' => 'usr/bin/ruby' }
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'File patterns attributes' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
        end
      end

      it 'allows to specify the source files' do
        @spec.source_files = ['lib_classes/**/*']
        @spec.attributes_hash['source_files'].should == ['lib_classes/**/*']
      end

      it 'allows to specify the public headers files' do
        @spec.public_header_files = ['include/**/*']
        @spec.attributes_hash['public_header_files'].should == ['include/**/*']
      end

      it 'allows to specify the private headers files' do
        @spec.private_header_files = ['private/**/*']
        @spec.attributes_hash['private_header_files'].should == ['private/**/*']
      end

      it 'allows to specify the frameworks bundles shipped with the Pod' do
        @spec.vendored_frameworks = ['Parse.framework']
        @spec.attributes_hash['vendored_frameworks'].should == ['Parse.framework']
      end

      it 'allows to specify the libraries shipped with the Pod' do
        @spec.vendored_libraries = ['libProj4.a']
        @spec.attributes_hash['vendored_libraries'].should == ['libProj4.a']
      end

      it 'allows to specify the resources bundles shipped with the Pod' do
        @spec.resource_bundles = { 'MapBox' => 'MapView/Map/Resources/*.png' }
        @spec.attributes_hash['resource_bundles'].should == { 'MapBox' => 'MapView/Map/Resources/*.png' }
      end

      it 'allows to specify the resources files' do
        @spec.resources = ['frameworks/CrashReporter.framework']
        @spec.attributes_hash['resources'].should == ['frameworks/CrashReporter.framework']
      end

      it 'allows to specify the paths to exclude' do
        @spec.exclude_files = ['Classes/**/unused.{h,m}']
        @spec.attributes_hash['exclude_files'].should == ['Classes/**/unused.{h,m}']
      end

      it 'allows to specify the paths to preserve' do
        @spec.preserve_paths = ['Frameworks/*.framework']
        @spec.attributes_hash['preserve_paths'].should == ['Frameworks/*.framework']
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Subspecs' do
      before do
        @spec = Spec.new do |_s|
        end
      end

      it 'allows to specify as subspec' do
        @spec = Spec.new do |s|
          s.name = 'Spec'
          s.subspec 'Subspec' do |_sp|
          end
        end
        subspec = @spec.subspecs.first
        subspec.parent.should == @spec
        subspec.class.should == Specification
        subspec.name.should == 'Spec/Subspec'
      end

      it 'should allow you to specify a preferred set of dependencies' do
        @spec.default_subspecs = 'Preferred-Subspec1', 'Preferred-Subspec2'
        @spec.attributes_hash['default_subspecs'].should == %w(Preferred-Subspec1 Preferred-Subspec2)
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Test specs' do
      before do
        @spec = Spec.new do |spec|
          spec.name = 'Spec'
          spec.test_spec do |test_spec|
            test_spec.test_type = :unit
          end
        end
      end

      it 'allows you to specify a test spec' do
        test_spec = @spec.subspecs.first
        test_spec.class.should == Specification
        test_spec.name.should == 'Spec/Tests'
        test_spec.test_specification?.should == true
        test_spec.test_type.should == :unit
      end

      it 'allows you to specify a test type as string' do
        a_spec = Spec.new do |spec|
          spec.name = 'Spec'
          spec.test_spec do |test_spec|
            test_spec.test_type = 'unit'
          end
        end
        test_spec = a_spec.subspecs.first
        test_spec.class.should == Specification
        test_spec.name.should == 'Spec/Tests'
        test_spec.test_specification?.should == true
        test_spec.test_type.should == :unit
      end

      it 'allows you to specify a scheme for a test spec' do
        a_spec = Spec.new do |spec|
          spec.name = 'Spec'
          spec.test_spec do |test_spec|
            test_spec.test_type = 'unit'
            test_spec.scheme = { :launch_arguments => %w(Arg1 Arg2), :environment_variables => { 'Key1' => 'Val1' } }
          end
        end
        test_spec = a_spec.subspecs.first
        test_spec.scheme.should == { :launch_arguments => %w(Arg1 Arg2), :environment_variables => { 'Key1' => 'Val1' } }
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Multi-Platform' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
        end
      end

      it 'allows to specify iOS attributes' do
        @spec.ios.preserve_paths = ['APath']
        @spec.attributes_hash['ios']['preserve_paths'].should == ['APath']
        @spec.attributes_hash['preserve_paths'].should.be.nil
        @spec.attributes_hash['osx'].should.be.nil
      end

      it 'allows to specify OS X attributes' do
        @spec.osx.preserve_paths = ['APath']
        @spec.attributes_hash['osx']['preserve_paths'].should == ['APath']
        @spec.attributes_hash['preserve_paths'].should.be.nil
        @spec.attributes_hash['ios'].should.be.nil
      end

      it 'allows to specify OS X attributes as macOS' do
        @spec.macos.preserve_paths = ['APath']
        @spec.attributes_hash['osx']['preserve_paths'].should == ['APath']
        @spec.attributes_hash['preserve_paths'].should.be.nil
        @spec.attributes_hash['ios'].should.be.nil
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Attributes default values' do
      it 'does requires arc by default' do
        attr = Specification::DSL.attributes[:requires_arc]
        attr.default(:ios).should == true
        attr.default(:osx).should == true
      end
    end

    #-----------------------------------------------------------------------------#

    describe 'Attributes singular form' do
      it 'allows to use the singular form the attributes which support it' do
        attributes = Specification::DSL.attributes.values
        singularized = attributes.select(&:singularize?)
        spec = Specification.new
        singularized.each do |attr|
          spec.should.respond_to(attr.writer_name)
        end
        singularized.map { |attr| attr.name.to_s }.sort.should == %w(
          authors compiler_flags default_subspecs frameworks libraries
          preserve_paths resource_bundles resources screenshots script_phases
          swift_versions vendored_frameworks vendored_libraries weak_frameworks
        )
      end
    end

    #-----------------------------------------------------------------------------#
  end
end
