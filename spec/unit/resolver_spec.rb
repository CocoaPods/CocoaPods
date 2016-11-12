require File.expand_path('../../spec_helper', __FILE__)

def dependency_graph_from_array(locked_dependencies)
  locked_dependencies.reduce(Molinillo::DependencyGraph.new) do |graph, dep|
    graph.add_vertex(dep.name, dep, true)
    graph
  end
end

def empty_graph
  Molinillo::DependencyGraph.new
end

module Pod
  describe Resolver do
    describe 'In general' do
      before do
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit', '1.5.2'
        end
        locked_deps = dependency_graph_from_array([Dependency.new('BlocksKit', '1.5.2')])
        @resolver = Resolver.new(config.sandbox, @podfile, locked_deps, config.sources_manager.all)
      end

      it 'returns the sandbox' do
        @resolver.sandbox.should == config.sandbox
      end

      it 'returns the podfile' do
        @resolver.podfile.should == @podfile
      end

      it 'returns the locked dependencies' do
        @resolver.locked_dependencies.
          should == dependency_graph_from_array([Dependency.new('BlocksKit', '1.5.2')])
      end

      #--------------------------------------#

      describe 'SpecificationProvider' do
        it 'does not return nil specifications in #search_for even when a ' \
          'subspec does not exist in all versions' do
          @resolver.instance_variable_set(:@cached_sets, {})
          possibilities = @resolver.search_for(Dependency.new('SDWebImage/Core'))
          possibilities.should.not.include? nil
        end
      end

      #--------------------------------------#

      it 'resolves the specification of the podfile' do
        target_definition = @podfile.target_definitions['Pods']
        specs = @resolver.resolve[target_definition]
        specs.map(&:to_s).should == [
          'A2DynamicDelegate (2.0.2)',
          'BlocksKit (1.5.2)',
          'libffi (3.0.13)',
        ]
      end

      it 'returns the resolved specifications grouped by target definition' do
        @resolver.resolve
        target_definition = @podfile.target_definitions['Pods']
        specs = @resolver.specs_by_target[target_definition]
        specs.map(&:to_s).should == [
          'A2DynamicDelegate (2.0.2)',
          'BlocksKit (1.5.2)',
          'libffi (3.0.13)',
        ]
      end

      it 'resolves specifications from external sources' do
        podspec = fixture('integration/Reachability/Reachability.podspec')
        spec = Specification.from_file(podspec)
        config.sandbox.expects(:specification).with('Reachability').returns(spec)
        podfile = Podfile.new do
          platform :ios
          pod 'Reachability', :podspec => podspec
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        resolver.resolve
        specs = resolver.specs_by_target.values.flatten
        specs.map(&:to_s).should == ['Reachability (3.0.0)']
      end

      it 'resolves an empty podfile' do
        @podfile = Podfile.new do
          platform :ios
        end
        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == []
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Resolution' do
      before do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'BlocksKit', '1.5.2'
        end
        @resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
      end

      it 'cross resolves dependencies' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking',    '<  0.9.2' # 0.9.1 exits
          pod 'AFQuickLookView', '=  0.1.0' # requires  'AFNetworking', '>= 0.9.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ['AFNetworking (0.9.1)', 'AFQuickLookView (0.1.0)']
      end

      it 'resolves basic conflicts' do
        @podfile = Podfile.new do
          platform :ios, '7.0'
          pod 'RestKit' # latest version (0.23.3) requires 'AFNetworking', '~> 1.3.0'
          pod 'AFNetworking', '~> 1.2.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ['AFNetworking (1.2.1)', 'RestKit (0.20.1)',
                         'RestKit/Core (0.20.1)', 'RestKit/CoreData (0.20.1)',
                         'RestKit/Network (0.20.1)', 'RestKit/ObjectMapping (0.20.1)',
                         'RestKit/Support (0.20.1)', 'SOCKit (1.1)', 'TransitionKit (1.1.0)']
      end

      it 'resolves three-way conflicts' do
        @podfile = Podfile.new do
          platform :ios, '7.0'
          pod 'AFAmazonS3Client' # latest version (2.0.0) requires 'AFNetworking', '~> 2.0'
          pod 'CargoBay' # latest version (2.1.0) requires 'AFNetworking', '~> 2.2'
          pod 'AFOAuth2Client' # latest version (0.1.2) requires 'AFNetworking', '~> 1.3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ['AFAmazonS3Client (1.0.1)', 'AFNetworking (1.3.4)',
                         'AFOAuth2Client (1.0.0)', 'CargoBay (1.0.0)']
      end

      it 'uses a Podfile requirement even when a previously declared ' \
        'dependency has a different requirement' do
          @podfile = Podfile.new do
            platform :ios, '7.0'
            pod 'InstagramKit' # latest version (3.7) requires 'AFNetworking', '~> 2.0'
            pod 'AFNetworking', '2.0.1'
          end

          resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
          specs = resolver.resolve.values.flatten.map(&:root).map(&:to_s).uniq.sort
          specs.should == ['AFNetworking (2.0.1)', 'InstagramKit (3.7)']
        end

      it 'holds the context state, such as cached specification sets' do
        @resolver.resolve
        cached_sets = @resolver.send(:cached_sets)
        cached_sets.values.sort_by(&:name).should == [
          config.sources_manager.search_by_name('A2DynamicDelegate').first,
          config.sources_manager.search_by_name('BlocksKit').first,
          config.sources_manager.search_by_name('libffi').first,
        ].sort_by(&:name)
      end

      it 'raises when a resolved dependency has a platform incompatibility' do
        @podfile = Podfile.new do
          platform :osx, '10.7'
          pod 'ReactiveCocoa', '0.16.1' # this version is iOS-only
        end
        @resolver.stubs(:podfile).returns(@podfile)
        should.raise Informative do
          @resolver.resolve
        end.message.should.match /platform .* not compatible/
      end

      it 'selects only platform-compatible versions' do
        @podfile = Podfile.new do
          platform :osx, '10.7'
          pod 'AFNetworking' # the most recent version requires 10.8
        end
        @resolver.stubs(:podfile).returns(@podfile)
        @resolver.resolve.values.flatten.map(&:to_s).sort.should == [
          'AFNetworking (1.3.4)',
        ]
      end

      it 'selects only platform-compatible versions for transitive dependencies' do
        spec = Pod::Spec.new do |s|
          s.name = 'lib'
          s.version = '1.0'
          s.platform = :ios, '5.0'
          s.subspec('Calendar') {}
          s.subspec('Classes') { |ss| ss.dependency 'lib/Calendar' }
          s.subspec('RequestManager') do |ss|
            ss.dependency 'lib/Classes'
            ss.dependency 'AFNetworking'
          end
          s.default_subspec = 'RequestManager'
        end
        @podfile = Podfile.new do
          platform :ios, '5.0'
          pod 'lib'
        end
        @resolver.stubs(:podfile).returns(@podfile)
        @resolver.send(:cached_sets)['lib'] = stub(:all_specifications => [spec])
        @resolver.resolve.values.flatten.map(&:to_s).sort.should == [
          'AFNetworking (1.3.4)', 'lib (1.0)', 'lib/Calendar (1.0)', 'lib/Classes (1.0)', 'lib/RequestManager (1.0)'
        ]
      end

      it 'raises an informative error when version conflicts are caused by platform incompatibilities' do
        @podfile = Podfile.new do
          platform :osx, '10.7'
          pod 'AFNetworking', '2.0.0' # requires 10.8
        end
        @resolver.stubs(:podfile).returns(@podfile)
        message = should.raise(Informative) { @resolver.resolve }.message
        message.should.match /required a higher minimum deployment target/
      end

      it 'raises an informative error when version conflict is caused by platform incompatibilities for local pods' do
        sandbox = config.sandbox
        local_spec = Specification.from_hash('name' => 'LocalPod', 'version' => '1.0', 'platforms' => { 'ios' => '8.0' })
        sandbox.stubs(:specification).with('LocalPod').returns(local_spec)
        @podfile = Podfile.new do
          target 'SampleProject' do
            platform :ios, '7.0'
            pod 'LocalPod', :path => '../'
          end
        end
        @resolver.stubs(:podfile).returns(@podfile)
        message = should.raise(Informative) { @resolver.resolve }.message
        message.should.match /required a higher minimum deployment target/
      end

      it 'raises if unable to find a specification' do
        Specification.any_instance.stubs(:all_dependencies).returns([Dependency.new('Windows')])
        message = should.raise Informative do
          @resolver.resolve
        end.message
        message.should.match /Unable to find a specification/
        message.should.match /`Windows` depended upon by `BlocksKit`/
      end

      it 'does not raise if all dependencies are supported by the platform of the target definition' do
        lambda { @resolver.resolve }.should.not.raise
      end

      it 'includes all the subspecs of a specification node' do
        @podfile = Podfile.new do
          platform :ios, '7.0'
          pod 'RestKit', '0.10.3'
        end
        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        resolver.resolve.values.flatten.map(&:name).sort.should == %w(
          FileMD5Hash
          ISO8601DateFormatter
          JSONKit
          LibComponentLogging-Core
          LibComponentLogging-NSLog
          NSData+Base64
          RestKit
          RestKit/JSON
          RestKit/Network
          RestKit/ObjectMapping
          RestKit/ObjectMapping/Core
          RestKit/ObjectMapping/CoreData
          RestKit/ObjectMapping/JSON
          RestKit/ObjectMapping/XML
          RestKit/UI
          SOCKit
          XMLReader
          cocoa-oauth
        )
      end

      it 'handles pre-release dependencies with subspecs' do
        @podfile = Podfile.new do
          platform :ios, '7.0'
          pod 'RestKit', '0.20.0-rc1'
        end
        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        resolver.resolve.values.flatten.map(&:to_s).sort.should == [
          'AFNetworking (1.1.0)',
          'RestKit (0.20.0-rc1)',
          'RestKit/Core (0.20.0-rc1)',
          'RestKit/CoreData (0.20.0-rc1)',
          'RestKit/Network (0.20.0-rc1)',
          'RestKit/ObjectMapping (0.20.0-rc1)',
          'RestKit/Support (0.20.0-rc1)',
          'SOCKit (1.1)',
        ]
      end

      it 'handles correctly subspecs from external sources' do
        @podfile = Podfile.new do
          platform :ios
          pod 'MainSpec/FirstSubSpec', :git => 'GIT-URL'
        end
        spec = Spec.new do |s|
          s.name         = 'MainSpec'
          s.version      = '1.2.3'
          s.platform     = :ios

          s.subspec 'FirstSubSpec' do |fss|
            fss.source_files = 'some/file'
            fss.subspec 'SecondSubSpec'
          end
        end
        config.sandbox.expects(:specification).with('MainSpec').returns(spec)
        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:name).sort
        specs.should == %w(
          MainSpec/FirstSubSpec MainSpec/FirstSubSpec/SecondSubSpec
        )
      end

      it 'allows pre-release spec versions when a requirement has an ' \
         'external source' do
        @podfile = Podfile.new do
          platform :ios
          pod 'MainSpec', :git => 'GIT-URL'
        end
        spec = Spec.new do |s|
          s.name         = 'MainSpec'
          s.version      = '1.2.3-pre'
          s.platform     = :ios
        end
        config.sandbox.expects(:specification).with('MainSpec').returns(spec)
        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == [
          'MainSpec (1.2.3-pre)',
        ]
      end

      it 'raises if it finds two conflicting explicit dependencies' do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.4'
          pod 'JSONKit', '1.5pre'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/Unable to satisfy the following requirements/)
        e.message.should.match(/`JSONKit \(= 1.4\)` required by `Podfile`/)
        e.message.should.match(/`JSONKit \(= 1.5pre\)` required by `Podfile`/)
      end

      it 'raises if it finds two conflicting dependencies' do
        podfile = Podfile.new do
          platform :ios, '8.0'
          pod 'RestKit', '0.23.3' # dependends on AFNetworking ~> 1.3.0
          pod 'AFNetworking', '> 2'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/Unable to satisfy the following requirements/)
        e.message.should.match(/`AFNetworking \(~> 1.3.0\)` required by `RestKit\/Network \(.*\)`/)
        e.message.should.match(/`AFNetworking \(> 2\)` required by `Podfile`/)
      end

      it 'raises if no such version of a dependency exists' do
        podfile = Podfile.new do
          platform :ios
          pod 'AFNetworking', '999.999.999'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/Unable to satisfy the following requirements/)
        e.message.should.match(/`AFNetworking \(= 999\.999\.999\)` required by `Podfile`/)
        e.message.should.match(/None of your spec sources contain a spec satisfying the dependency: `AFNetworking \(= 999\.999\.999\)`./)
        e.message.should.match(/You have either:/)
        e.message.should.match(/ * out-of-date source repos which you can update with `pod repo update`/)
        e.message.should.match(/ * not added the source repo that hosts the Podspec to your Podfile./)
        e.message.should.match(/ * out-of-date source repos which you can update with `pod repo update`/)
        e.message.should.match(/Note: as of CocoaPods 1.0, `pod repo update` does not happen on `pod install` by default./)
      end

      it 'raises with a list of dependencies if there are many dependencies but no versions of a dependency exists' do
        podfile = Podfile.new do
          platform :ios
          pod 'AFNetworking', '3.0.1'
        end
        locked_deps = dependency_graph_from_array([Dependency.new('AFNetworking', '= 1.4')])

        resolver = Resolver.new(config.sandbox, podfile, locked_deps, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/Unable to satisfy the following requirements/)
        e.message.should.match(/`AFNetworking \(= 3.0.1\)` required by `Podfile`/)
        e.message.should.match(/`AFNetworking \(= 1.4\)` required by `Podfile.lock`/)
        e.message.should.match(/None of your spec sources contain a spec satisfying the dependencies:/)
        e.message.should.match(/`AFNetworking \(= 3.0.1\), AFNetworking \(= 1.4\)`/)
        e.message.should.match(/You have either:/)
        e.message.should.match(/ * out-of-date source repos which you can update with `pod repo update`/)
        e.message.should.match(/ * not added the source repo that hosts the Podspec to your Podfile./)
        e.message.should.match(/ * out-of-date source repos which you can update with `pod repo update`/)
        e.message.should.match(/Note: as of CocoaPods 1.0, `pod repo update` does not happen on `pod install` by default./)
      end

      it 'takes into account locked dependencies' do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '<= 1.5pre'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        version = resolver.resolve.values.flatten.first.version
        version.to_s.should == '1.5pre'

        locked_deps = dependency_graph_from_array([Dependency.new('JSONKit', '= 1.4')])
        resolver = Resolver.new(config.sandbox, podfile, locked_deps, config.sources_manager.all)
        version = resolver.resolve.values.flatten.first.version
        version.to_s.should == '1.4'
      end

      it 'shows a helpful error message if the old resolver incorrectly ' \
         'activated a pre-release version that now leads to a version ' \
         'conflict' do
        podfile = Podfile.new do
          platform :ios, '8.0'
          pod 'CocoaLumberjack'
        end
        locked_deps = dependency_graph_from_array([Dependency.new('CocoaLumberjack', '= 2.0.0-beta2')])
        resolver = Resolver.new(config.sandbox, podfile, locked_deps, config.sources_manager.all)
        e = lambda { puts resolver.resolve.values.flatten }.should.raise Informative
        e.message.should.match(/you were using a pre-release version of `CocoaLumberjack`/)
        e.message.should.match(/`pod 'CocoaLumberjack', '= 2.0.0-beta2'`/)
        e.message.should.match(/`pod update CocoaLumberjack`/)
      end

      describe 'concerning dependencies that are scoped by consumer platform' do
        def resolve
          Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all).resolve
        end

        # AFNetworking Has an 'AFNetworking/UIKit' iOS-only default subspec
        requirement = ['AFNetworking', '2.4.1']
        ios_subspec = 'AFNetworking/UIKit (2.4.1)'

        it 'excludes those for another platform' do
          @podfile = Podfile.new do
            platform :osx, '10.10'
            pod(*requirement)
          end
          resolve.values.flatten.map(&:to_s).should.not.include ios_subspec
        end

        it 'includes those for the requested platform' do
          @podfile = Podfile.new do
            platform :ios, '7'
            pod(*requirement)
          end
          resolve.values.flatten.map(&:to_s).should.include ios_subspec
        end

        it 'includes those in the target for the requested platform only' do
          @podfile = Podfile.new do
            target 'iOS' do
              platform :ios, '7'
              pod(*requirement)
            end
            target 'OSX' do
              platform :osx, '10.10'
              pod(*requirement)
            end
          end
          resolved = resolve
          ios_target = resolved.keys.find { |td| td.label == 'Pods-iOS' }
          osx_target = resolved.keys.find { |td| td.label == 'Pods-OSX' }
          resolved[ios_target].map(&:to_s).should.include ios_subspec
          resolved[osx_target].map(&:to_s).should.not.include ios_subspec
        end

        it 'includes dependencies in the target for the requested platform only' do
          osx_dependency = 'ARAnalytics/CoreMac (4.0.1)'
          ios_dependency = 'ARAnalytics/CoreIOS (4.0.1)'
          @podfile = Podfile.new do
            target 'iOS' do
              platform :ios, '8'
              pod 'ARAnalytics', '4.0.1'
            end
            target 'OSX' do
              platform :osx, '10.10'
              pod 'ARAnalytics', '4.0.1'
            end
          end
          resolved = resolve
          ios_target = resolved.keys.find { |td| td.label == 'Pods-iOS' }
          osx_target = resolved.keys.find { |td| td.label == 'Pods-OSX' }
          resolved[ios_target].map(&:to_s).should.include ios_dependency
          resolved[osx_target].map(&:to_s).should.not.include ios_dependency
          resolved[ios_target].map(&:to_s).should.not.include osx_dependency
          resolved[osx_target].map(&:to_s).should.include osx_dependency
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Multiple sources' do
      it 'consults all sources when finding a matching spec' do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '> 2'
        end
        file = fixture('spec-repos/test_repo/JSONKit/999.999.999/JSONKit.podspec')
        sources = config.sources_manager.sources(%w(master test_repo))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        spec = resolver.resolve.values.flatten.first
        spec.version.to_s.should == '999.999.999'
        spec.defined_in_file.should == file

        sources = config.sources_manager.sources(%w(test_repo master))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        spec = resolver.resolve.values.flatten.first
        spec.version.to_s.should == '999.999.999'
        resolver.resolve.values.flatten.first.defined_in_file.should == file
      end

      it 'warns and chooses the first source when multiple sources contain ' \
         'a pod' do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.4'
        end
        sources = config.sources_manager.sources(%w(master test_repo))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        spec = resolver.resolve.values.flatten.first
        spec.version.to_s.should == '1.4'
        spec.defined_in_file.should == fixture('spec-repos/master/Specs/1/3/f/JSONKit/1.4/JSONKit.podspec.json')

        sources = config.sources_manager.sources(%w(test_repo master))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        spec = resolver.resolve.values.flatten.first
        spec.version.to_s.should == '1.4'
        resolver.resolve.values.flatten.first.defined_in_file.should == fixture('spec-repos/test_repo/JSONKit/1.4/JSONKit.podspec')

        UI.warnings.should.match /multiple specifications/
      end

      it 'does not warn when multiple sources contain a pod but a dependency ' \
         'has an explicit source specified' do
        test_repo_url = config.sources_manager.source_with_name_or_url('test_repo').url
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.4', :source => test_repo_url
        end

        sources = config.sources_manager.sources(%w(master test_repo))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        resolver.resolve

        UI.warnings.should.not.match /multiple specifications/
      end

      it 'fails to resolve a dependency with an explicit source even if it can be ' \
         'resolved using the global sources' do
        test_repo_url = config.sources_manager.source_with_name_or_url('test_repo').url
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.5pre', :source => test_repo_url
        end

        sources = config.sources_manager.sources(%w(master))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/None of your spec sources contain a spec/)
        e.message.should.match(/JSONKit/)
        e.message.should.match(/\= 1.5pre/)
      end

      it 'resolves a dependency with an explicit source even if it can\'t be ' \
         'resolved using the global sources' do
        master_repo_url = config.sources_manager.source_with_name_or_url('master').url
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.5pre', :source => master_repo_url
        end

        sources = config.sources_manager.sources(%w(test_repo))
        sources.map(&:url).should.not.include(master_repo_url)
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        spec = resolver.resolve.values.flatten.first
        spec.version.to_s.should == '1.5pre'
        spec.defined_in_file.should == fixture('spec-repos/master/Specs/1/3/f/JSONKit/1.5pre/JSONKit.podspec.json')
      end

      it 'uses explicit source repos for a dependency even when it\'s transitive' do
        master_repo_url = config.sources_manager.source_with_name_or_url('master').url
        test_repo_url = config.sources_manager.source_with_name_or_url('test_repo').url

        podfile = Podfile.new do
          platform :ios
          # KeenClient has a dependency on JSONKit 1.4
          pod 'KeenClient', '3.2.2', :source => master_repo_url
          pod 'JSONKit', '1.4', :source => test_repo_url
        end

        sources = config.sources_manager.sources(%w(master test_repo))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        resolver.resolve

        possible_specs = resolver.search_for(Dependency.new('JSONKit', '1.4'))

        # JSONKit, v1.4 exists in both repos, but we should only ever be offered the test_repo version.
        possible_specs.count.should == 1
        possible_specs.first.version.to_s.should == '1.4'
        possible_specs.first.defined_in_file.should == fixture('spec-repos/test_repo/JSONKit/1.4/JSONKit.podspec')
      end

      it 'uses global source repos for resolving a transitive dependency even ' \
         'if the root dependency has an explicit source' do
        test_repo_url = config.sources_manager.source_with_name_or_url('test_repo').url
        podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'CrossRepoDependent', '1.0', :source => test_repo_url
        end

        # CrossRepoDependent depends on AFNetworking which is only available in the master repo.
        sources = config.sources_manager.sources(%w(master))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)
        resolver.resolve

        specs = resolver.resolve.values.flatten

        specs.map(&:name).should ==
          %w(AFNetworking AFNetworking/NSURLConnection AFNetworking/NSURLSession AFNetworking/Reachability) +
            %w(AFNetworking/Security AFNetworking/Serialization AFNetworking/UIKit CrossRepoDependent)

        afnetworking_spec = specs.find { |s| s.name == 'AFNetworking' }
        afnetworking_spec.should.not.be.nil
        afnetworking_spec.defined_in_file.should == fixture('spec-repos/master/Specs/a/7/5/AFNetworking/2.4.0/AFNetworking.podspec.json')

        # Check that if the master source is not available the dependency cannot be resolved.
        sources = config.sources_manager.sources(%w(test_repo))
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, sources)

        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/Unable to find a specification for/)
        e.message.should.match(/`AFNetworking \(= 2.4.0\)`/)
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Pre-release versions' do
      it 'resolves explicitly requested pre-release versions' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '1.0RC3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ['AFNetworking (1.0RC3)']
      end

      it 'resolves to latest minor version even when explicitly requesting pre-release versions when using ~>' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '~> 1.0RC3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.3.4)']
      end

      it 'does not resolve to a pre-release version implicitly when matching exact version' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '1.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.0)']
      end

      it 'does not resolve to a pre-release version implicitly when using <' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '< 1.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (0.10.1)']
      end

      it 'does not resolve to a pre-release version implicitly when using <=' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '<= 1.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.0)']
      end

      it 'does not resolve to a pre-release version implicitly when using >' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '> 1.0', '< 1.3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.2.1)']
      end

      it 'does not resolve to a pre-release version implicitly when using >=' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '>= 1.0', '< 1.3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.2.1)']
      end

      it 'does not resolve to a pre-release version implicitly when using ~>' do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking', '~> 1.0', '< 1.3'
        end

        resolver = Resolver.new(config.sandbox, @podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should != ['AFNetworking (1.0RC3)']
        specs.should == ['AFNetworking (1.2.1)']
      end

      it 'raises when no constraints are specified and only pre-release versions are available' do
        podfile = Podfile.new do
          platform :ios
          pod 'PrereleaseMonkey'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/There are only pre-release versions available satisfying the following requirements/)
        e.message.should.match(/PrereleaseMonkey.*>= 0/)
        e.message.should.match(/You should explicitly specify the version in order to install a pre-release version/)
      end

      it 'raises when no explicit version is specified and only pre-release versions satisfy constraints' do
        podfile = Podfile.new do
          platform :ios
          pod 'AFNetworking', '< 1.0', '> 0.10.1'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        e = lambda { resolver.resolve }.should.raise Informative
        e.message.should.match(/There are only pre-release versions available satisfying the following requirements/)
        e.message.should.match(/AFNetworking.*< 1\.0, > 0\.10\.1/)
        e.message.should.match(/You should explicitly specify the version in order to install a pre-release version/)
      end

      it 'resolves when there is explicit pre-release version specified and there are only pre-release versions' do
        podfile = Podfile.new do
          platform :ios
          pod 'PrereleaseMonkey', '1.0-beta1'
        end
        resolver = Resolver.new(config.sandbox, podfile, empty_graph, config.sources_manager.all)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ['PrereleaseMonkey (1.0-beta1)']
      end
    end
  end
end
