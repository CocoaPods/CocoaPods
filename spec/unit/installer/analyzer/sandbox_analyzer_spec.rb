require File.expand_path('../../../../spec_helper', __FILE__)

#-----------------------------------------------------------------------------#

module Pod
  describe Installer::Analyzer::SandboxAnalyzer do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @sandbox = config.sandbox
      lockfile_hash = { 'PODS' => ['BananaLib (1.0)'] }
      @manifest = Pod::Lockfile.new(lockfile_hash)
      @sandbox.stubs(:manifest).returns(@manifest)
      @analyzer = Installer::Analyzer::SandboxAnalyzer.new(@sandbox, [@spec], false)
    end

    #-------------------------------------------------------------------------#

    describe 'Analysis' do
      it 'returns the sandbox state' do
        @analyzer.stubs(:folder_exist?).returns(true)
        @analyzer.stubs(:folder_empty?).returns(false)
        @analyzer.stubs(:sandbox_checksum).returns(@spec.checksum)
        state = @analyzer.analyze
        state.class.should == Installer::Analyzer::SpecsState
        state.unchanged.should == Set.new(%w(BananaLib))
      end

      it 'marks all the pods as added if no sandbox manifest is available' do
        @sandbox.stubs(:manifest)
        @analyzer.analyze.added.should == Set.new(%w(BananaLib))
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Analysis' do
      before do
        @analyzer.stubs(:folder_exist?).returns(true)
        @analyzer.stubs(:folder_empty?).returns(false)
        @analyzer.stubs(:sandbox_checksum).returns(@spec.checksum)
      end

      it 'returns whether a Pod is unchanged' do
        @analyzer.send(:pod_state, 'BananaLib').should == :unchanged
      end

      it 'considers a Pod as added if it is not recorded in the sandbox manifest' do
        @analyzer.stubs(:sandbox_pods).returns([])
        @analyzer.send(:pod_added?, 'BananaLib').should == true
      end

      it "considers a Pod as added if it folder doesn't exits" do
        @analyzer.stubs(:folder_exist?).returns(false)
        @analyzer.send(:pod_added?, 'BananaLib').should == true
      end

      it 'considers a deleted Pod without any resolved specification' do
        @analyzer.stubs(:resolved_pods).returns([])
        @analyzer.send(:pod_deleted?, 'BananaLib').should == true
      end

      it 'considers a changed Pod whose versions do not match' do
        @analyzer.stubs(:sandbox_version).returns(Version.new(999))
        @analyzer.send(:pod_changed?, 'BananaLib').should == true
      end

      it 'considers a changed Pod whose checksums do not match' do
        @analyzer.stubs(:sandbox_checksum).returns('SHA')
        @analyzer.send(:pod_changed?, 'BananaLib').should == true
      end

      it 'considers a changed Pod whose activated specifications do not match' do
        @analyzer.stubs(:sandbox_spec_names).returns(['BananaLib', 'BananaLib/Subspec'])
        @analyzer.send(:pod_changed?, 'BananaLib').should == true
      end

      it 'considers a changed Pod whose folder is empty' do
        @analyzer.stubs(:folder_empty?).returns(true)
        @analyzer.send(:pod_changed?, 'BananaLib').should == true
      end

      it 'considers a changed Pod which has been pre-downloaded' do
        @sandbox.stubs(:predownloaded?).returns(true)
        @analyzer.send(:pod_changed?, 'BananaLib').should == true
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      it 'returns the sandbox manifest' do
        @analyzer.send(:sandbox_manifest).should == @manifest
      end

      it 'returns the lockfile as the sandbox if one is not available' do
        lockfile = Lockfile.new({})
        @sandbox.stubs(:manifest)
        @analyzer.stubs(:lockfile).returns(lockfile)
        @analyzer.send(:sandbox_manifest).should == lockfile
      end

      #--------------------------------------#

      it 'returns the root name of the resolved Pods' do
        subspec = Spec.new(@spec, 'Subspec')
        @analyzer.stubs(:specs).returns([@spec, subspec])
        @analyzer.send(:resolved_pods).should == ['BananaLib']
      end

      it 'returns the root name of pods stored in the sandbox manifest' do
        @manifest.stubs(:pod_names).returns(['BananaLib', 'BananaLib/Subspec'])
        @analyzer.send(:sandbox_pods).should == ['BananaLib']
      end

      it 'returns the name of the resolved specifications sorted by name' do
        subspec = Spec.new(@spec, 'Subspec')
        @analyzer.stubs(:specs).returns([subspec, @spec])
        @analyzer.send(:resolved_spec_names, 'BananaLib').should == ['BananaLib', 'BananaLib/Subspec']
      end

      it 'returns the name of the specifications stored in the sandbox manifest' do
        @manifest.stubs(:pod_names).returns(['BananaLib', 'BananaLib/Subspec'])
        @analyzer.send(:sandbox_spec_names, 'BananaLib').should == ['BananaLib', 'BananaLib/Subspec']
      end

      it 'returns the root specification for the Pod with the given name' do
        subspec = Spec.new(@spec, 'Subspec')
        @analyzer.stubs(:specs).returns([@spec, subspec])
        @analyzer.send(:root_spec, 'BananaLib').should == @spec
      end

      #--------------------------------------#

      it 'returns the version for the Pod with the given name stored in the manifest' do
        @analyzer.send(:sandbox_version, 'BananaLib').should == Version.new('1.0')
      end

      it 'returns the checksum for the spec of the Pods with the given name stored in the manifest' do
        @manifest.stubs(:checksum).returns(@spec.checksum)
        @analyzer.send(:sandbox_checksum, 'BananaLib').should == @spec.checksum
      end

      #--------------------------------------#

      it 'returns whether the folder containing the Pod with the given name exists' do
        @analyzer.send(:folder_exist?, 'BananaLib').should.be.false
        path = temporary_directory + 'Pods/BananaLib'
        path.mkpath
        @analyzer.send(:folder_exist?, 'BananaLib').should.be.true
      end

      it 'returns whether the folder containing the Pod with the given name is empty' do
        @analyzer.send(:folder_empty?, 'BananaLib').should.be.true
        path = temporary_directory + 'Pods/BananaLib'
        path.mkpath
        File.open(path + 'file', 'w') {}
        @analyzer.send(:folder_empty?, 'BananaLib').should.be.false
      end
    end

    #-------------------------------------------------------------------------#
  end
end
