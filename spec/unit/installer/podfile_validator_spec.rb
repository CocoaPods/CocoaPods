require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodfileValidator do
    describe 'podspec/path in combination with other download strategies' do
      it 'validates that podspec is not used in combination with other download strategies' do
        podfile = Pod::Podfile.new do
          abstract!(false)
          pod 'JSONKit', :podspec => 'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/JSONKit/1.5pre/JSONKit.podspec.json',
                         :git => 'git@github.com:johnezang/JSONKit.git'
        end

        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.valid?.should.be.false
        validator.errors.size.should == 1
        validator.errors[0].should.match /The dependency `JSONKit` specifies `podspec` or `path`/
      end

      it 'validates that path is not used in combination with other download strategies' do
        podfile = Pod::Podfile.new do
          abstract!(false)
          pod 'JSONKit', :path => './JSONKit/1.5pre/JSONKit.podspec.json',
                         :git => 'git@github.com:johnezang/JSONKit.git'
        end

        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.valid?.should.be.false
        validator.errors.size.should == 1
        validator.errors[0].should.match /The dependency `JSONKit` specifies `podspec` or `path`/
      end

      it 'validates when calling `valid?` before calling `validate`' do
        podfile = Pod::Podfile.new do
          abstract!(false)
          pod 'JSONKit', :path => './JSONKit/1.5pre/JSONKit.podspec.json',
                         :git => 'git@github.com:johnezang/JSONKit.git'
        end

        validator = Installer::PodfileValidator.new(podfile)
        validator.valid?

        validator.valid?.should.be.false
      end
    end

    describe 'multiple download strategies' do
      it 'validates that only one download strategy is specified' do
        podfile = Pod::Podfile.new do
          abstract!(false)
          pod 'JSONKit', :svn => 'svn.example.com/JSONKit',
                         :git => 'git@github.com:johnezang/JSONKit.git'
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.valid?.should.be.false
        validator.errors.size.should == 1
        validator.errors[0].should.match /The dependency `JSONKit` specifies more than one/
      end
    end
  end
end
