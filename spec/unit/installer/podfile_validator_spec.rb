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

    describe 'empty podfiles' do
      it 'warns if the podfile does not contain any dependency' do
        podfile = Pod::Podfile.new
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.be.valid
        validator.errors.should.be.empty
        validator.warnings.should == ['The Podfile does not contain any dependencies.']
      end
    end

    describe 'abstract-only dependencies' do
      it 'errors when there is only a root target' do
        podfile = Pod::Podfile.new do
          pod 'Alamofire'
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The dependency `Alamofire` is not used in any concrete target.']
      end

      it 'errors when there are only abstract targets' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The dependency `Alamofire` is not used in any concrete target.']
      end

      it 'does not error when an abstract target has concrete children with complete inheritance' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
            target 'Concrete'
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.be.valid
        validator.errors.should.be.empty
      end

      it 'errors when an abstract target has concrete children with no inheritance' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
            target 'Concrete' do
              inherit! :none
            end
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The dependency `Alamofire` is not used in any concrete target.']
      end

      it 'errors when an abstract target has concrete children with only search_paths inheritance' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
            target 'Concrete' do
              inherit! :search_paths
            end
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The dependency `Alamofire` is not used in any concrete target.']
      end

      it 'does not error when an abstract target has multiple children with varied inheritance' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
            target 'Concrete' do
              inherit! :none
            end
            target 'Other Concrete' do
            end
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.be.valid
        validator.errors.should.be.empty
      end

      it 'does not error when an abstract target has multiple children with varied inheritance' do
        podfile = Pod::Podfile.new do
          abstract_target 'Abstract' do
            pod 'Alamofire'
            target 'Concrete' do
              inherit! :search_paths
            end
            target 'Other Concrete' do
            end
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.be.valid
        validator.errors.should.be.empty
      end
    end

    describe 'duplicated targets' do
      it 'errors when the same target is declared twice' do
        podfile = Pod::Podfile.new do
          pod 'Alamofire'
          target 'Target'
          target 'Target'
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The target `Target` is declared twice.']
      end

      it 'errors when the same target is declared twice when using a custom xcodeproj' do
        podfile = Pod::Podfile.new do
          pod 'Alamofire'
          target 'Target' do
            xcodeproj 'Project.xcodeproj'
          end
          target 'Target' do
            xcodeproj 'Project.xcodeproj'
          end
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.not.be.valid
        validator.errors.should == ['The target `Target` is declared twice for the project `Project.xcodeproj`.']
      end

      it 'does not error when the same target is declared twice for different projects' do
        podfile = Pod::Podfile.new do
          pod 'Alamofire'
          target 'Target' do
            xcodeproj 'Project.xcodeproj'
          end
          target 'Target' do
            xcodeproj 'Project 1.xcodeproj'
          end
          target 'Target'
        end
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        validator.should.be.valid
      end
    end
  end
end
