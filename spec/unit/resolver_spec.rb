require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Resolver do
    describe "In general" do
      before do
        config.repos_dir = fixture('spec-repos')
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit', '1.5.2'
        end
        locked_deps = [Dependency.new('BlocksKit', '1.5.2')]
        @resolver = Resolver.new(config.sandbox, @podfile, locked_deps)
      end

      it "returns the sandbox" do
        @resolver.sandbox.should == config.sandbox
      end

      it "returns the podfile" do
        @resolver.podfile.should == @podfile
      end

      it "returns the locked dependencies" do
        @resolver.locked_dependencies.should == [Dependency.new('BlocksKit', '1.5.2')]
      end

      it "allows to specify whether the external sources should be updated against the remote" do
        # TODO
        @resolver.update_external_specs = true
        @resolver.update_external_specs.should.be.true
      end

      #--------------------------------------#

      it "resolves the specification of the podfile" do
        target_definition = @podfile.target_definitions[:default]
        specs = @resolver.resolve[target_definition]
        specs.map(&:to_s).should == [
          "A2DynamicDelegate (2.0.2)",
          "BlocksKit (1.5.2)",
          "libffi (3.0.11)"
        ]
      end

      it "returns the resolved specifications grouped by target definition" do
        @resolver.resolve
        target_definition = @podfile.target_definitions[:default]
        specs = @resolver.specs_by_target[target_definition]
        specs.map(&:to_s).should == [
          "A2DynamicDelegate (2.0.2)",
          "BlocksKit (1.5.2)",
          "libffi (3.0.11)"
        ]
      end

      it "returns all the resolved specifications" do
        @resolver.resolve
        @resolver.specs.map(&:class).uniq.should == [Specification]
        @resolver.specs.map(&:to_s).should == [
          "A2DynamicDelegate (2.0.2)",
          "BlocksKit (1.5.2)",
          "libffi (3.0.11)"
        ]
      end

      xit "returns the specifications that originated from external sources" do

      end
    end

    #-------------------------------------------------------------------------#

    describe "Resolution" do
      before do
        config.repos_dir = fixture('spec-repos')
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'BlocksKit', '1.5.2'
        end
        @resolver = Resolver.new(config.sandbox, @podfile)
      end


      it "holds the context state, such as cached specification sets" do
        @resolver.resolve
        cached_sets = @resolver.send(:cached_sets)
        cached_sets.values.sort_by(&:name).should == [
          Source.search_by_name('A2DynamicDelegate').first,
          Source.search_by_name('BlocksKit').first,
          Source.search_by_name('libffi').first
        ].sort_by(&:name)
      end

      it "raises once any of the dependencies does not match the platform of its podfile target" do
        Specification.any_instance.stubs(:available_platforms).returns([Platform.new(:ios, '999')])
        e = lambda { @resolver.resolve }.should.raise Informative
        e.message.should.match(/platform .* not compatible/)
      end

      it "does not raise if all dependencies are supported by the platform of the target definition" do
        lambda { @resolver.resolve }.should.not.raise
      end

      it "includes all the subspecs of a specification node" do
        @podfile = Podfile.new do
          platform :ios
          pod 'RestKit'
        end
        resolver = Resolver.new(config.sandbox, @podfile)
        resolver.resolve.values.flatten.map(&:name).sort.should == %w{
        FileMD5Hash
        ISO8601DateFormatter
        JSONKit
        LibComponentLogging-Core
        LibComponentLogging-NSLog
        NSData+Base64
        RestKit
        RestKit/JSON
        RestKit/Network
        RestKit/ObjectMapping/CoreData
        RestKit/ObjectMapping/JSON
        RestKit/UI
        SOCKit
        cocoa-oauth
        }
      end

      it "resolves subspecs with external constraints" do
        @podfile = Podfile.new do
          platform :ios
          pod 'MainSpec/FirstSubSpec', :git => 'GIT-URL'
        end
        spec = Spec.new do |s|
          s.name         = 'MainSpec'
          s.version      = '1.2.3'
          s.platform     = :ios
          s.license      = 'MIT'
          s.author       = 'Joe the Plumber'
          s.summary      = 'A spec with subspecs'
          s.source       = { :git => '/some/url' }
          s.requires_arc = true

          s.subspec 'FirstSubSpec' do |fss|
            fss.source_files = 'some/file'
            fss.subspec 'SecondSubSpec'
          end
        end
        ExternalSources::GitSource.any_instance.stubs(:specification_from_sandbox).returns(spec)
        resolver = Resolver.new(config.sandbox, @podfile)
        resolver.resolve.values.flatten.map(&:name).sort.should == %w{ MainSpec/FirstSubSpec MainSpec/FirstSubSpec/SecondSubSpec }
      end

      it "marks a specification's version to be a `bleeding edge' version" do
        podfile = Podfile.new do
          platform :ios
          pod 'FileMD5Hash'
          pod 'JSONKit', :head
        end
        resolver = Resolver.new(config.sandbox, podfile)
        filemd5hash, jsonkit = resolver.resolve.values.first.sort_by(&:name)
        filemd5hash.version.should.not.be.head
        jsonkit.version.should.be.head
      end

      it "raises if it finds two conflicting dependencies" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', "1.4"
          pod 'JSONKit', "1.5pre"
        end
        resolver = Resolver.new(config.sandbox, podfile)
        e = lambda {resolver.resolve}.should.raise Pod::StandardError
        e.message.should.match(/already activated version/)
      end

      xit "is robust against infinite loops" do

      end

      xit "takes into account locked dependencies" do

      end

      xit "transfers the head state of a dependency to a specification" do

      end

      xit "" do

      end

      xit "" do

      end

      xit "" do

      end

      # describe "Concerning Installation mode" do
      #   before do
      #     config.repos_dir = fixture('spec-repos')
      #     @podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit', '1.5.2'
      #       pod 'JSONKit'
      #     end
      #     @specs = [
      #       Specification.new do |s|
      #         s.name = "BlocksKit"
      #         s.version = "1.5.2"
      #       end,
      #       Specification.new do |s|
      #         s.name = "JSONKit"
      #         s.version = "1.4"
      #       end ]
      #     @specs.each { |s| s.activate_platform(:ios) }
      #     @resolver = Resolver.new(@podfile, @lockfile, stub('sandbox'))
      #   end

      #   it "doesn't install pods still compatible with the Podfile" do
      #     @resolver.resolve
      #     @resolver.should_install?("BlocksKit").should.be.false
      #     @resolver.should_install?("JSONKit").should.be.false
      #   end

      #   it "doesn't update the version of pods still compatible with the Podfile" do
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.should.include? "JSONKit (1.4)"
      #   end

      #   it "doesn't include pods removed from the Podfile" do
      #     podfile = Podfile.new { platform :ios; pod 'JSONKit' }
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve.values.flatten.map(&:name).should == %w{ JSONKit }
      #   end

      #   it "reinstalls pods updated in the Podfile" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'JSONKit', '1.5pre'
      #       pod 'BlocksKit', '1.5.2'
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.should.include? "BlocksKit (1.5.2)"
      #     installed.should.include? "JSONKit (1.5pre)"
      #   end

      #   it "installs pods added to the Podfile" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'JSONKit'
      #       pod 'BlocksKit'
      #       pod 'libPusher', '1.3' # New pod
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.should.include? "libPusher (1.3)"
      #   end

      #   it "handles head pods" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'JSONKit', :head   # Existing pod switched to head mode
      #       pod 'libPusher', :head # New pod
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #     @resolver.should_install?("JSONKit").should.be.true
      #     @resolver.should_install?("libPusher").should.be.true
      #   end

      #   it "handles pods from external dependencies" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'libPusher', :git => 'GIT-URL'
      #     end
      #     spec = Spec.new do |s|
      #       s.name         = 'libPusher'
      #       s.version      = '1.3'
      #     end
      #     ExternalSources::GitSource.any_instance.stubs(:specification_from_sandbox).returns(spec)
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #     @resolver.should_install?("JSONKit").should.be.false
      #   end

      #   it "doesn't updates the repos if there no change in the pods" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit'
      #       pod 'JSONKit'
      #     end
      #     config.skip_repo_update = false
      #     Command::Repo.any_instance.expects(:run).never
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #   end

      #   it "updates the repos if there is a new pod" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit'
      #       pod 'JSONKit'
      #       pod 'libPusher' # New pod
      #     end
      #     config.skip_repo_update = false
      #     Command::Repo::Update.any_instance.expects(:run).once
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #   end

      #   it "doesn't update the repos if config indicate to skip it in any case" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit'
      #       pod 'JSONKit', :head #changed to head
      #       pod 'libPusher'      # New pod
      #     end
      #     config.skip_repo_update = true
      #     Command::Repo::Update.any_instance.expects(:run).never
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #   end

      #   it "updates the repos if there is a new pod" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit'
      #       pod 'JSONKit', :head #changed to head
      #     end
      #     config.skip_repo_update = false
      #     Command::Repo::Update.any_instance.expects(:run).once
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.resolve
      #   end
      # end

      # describe "Concerning Update mode" do
      #   before do
      #     config.repos_dir = fixture('spec-repos')
      #     previous_podfile = Podfile.new do
      #       platform :ios
      #       pod 'JSONKit'
      #       pod 'libPusher'
      #     end
      #     @specs = [
      #       Specification.new do |s|
      #         s.name = "libPusher"
      #         s.version = "1.3"
      #       end,
      #       Specification.new do |s|
      #         s.name = "JSONKit"
      #         s.version = "1.4"
      #       end ]
      #     @specs.each { |s| s.activate_platform(:ios) }
      #     @lockfile = Lockfile.generate(previous_podfile, @specs)
      #     @podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit', '1.5.2'
      #       pod 'JSONKit'
      #       pod 'libPusher'
      #     end
      #     @resolver = Resolver.new(@podfile, @lockfile, stub('sandbox'))
      #     @resolver.update_mode = true
      #   end

      #   it "identifies the pods that can be updated" do
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.should.include? "JSONKit (999.999.999)"
      #     @resolver.should_install?("JSONKit").should.be.true
      #   end

      #   it "respects the constraints of the podfile" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'BlocksKit', '1.5.2'
      #       pod 'JSONKit', '1.4'
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.update_mode = true
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.should.include? "JSONKit (1.4)"
      #     @resolver.should_install?("JSONKit").should.be.false
      #   end

      #   it "installs new pods" do
      #     installed = @resolver.resolve.values.flatten.map(&:to_s)
      #     installed.join(' ').should.include?('BlocksKit')
      #     @resolver.should_install?("BlocksKit").should.be.true
      #   end

      #   it "it always suggests to update pods in head mode" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'libPusher', :head
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.update_mode = true
      #     @resolver.resolve
      #     @resolver.should_install?("libPusher").should.be.true
      #   end

      #   it "always updates the repos even if there is change in the pods" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'JSONKit'
      #       pod 'libPusher'
      #     end
      #     config.skip_repo_update = false
      #     Command::Repo::Update.any_instance.expects(:run).once
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.update_mode = true
      #     @resolver.resolve
      #   end

      #   # TODO: stub the specification resolution for the sandbox
      #   xit "it always suggests to update pods from external sources" do
      #     podfile = Podfile.new do
      #       platform :ios
      #       pod 'libPusher', :git => "example.com"
      #     end
      #     @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
      #     @resolver.update_mode = true
      #     @resolver.resolve
      #     @resolver.should_install?("libPusher").should.be.true
      #   end
      # end
    end
  end
end
