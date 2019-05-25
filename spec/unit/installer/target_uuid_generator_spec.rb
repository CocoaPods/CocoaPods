require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Installer
    describe TargetUUIDGenerator do
      before do
        @project = Project.new('Project.xcodeproj')
        @project.new_target(:static_library, 'NativeTarget1', :ios)
        @target_uuid_generator = TargetUUIDGenerator.new(@project)
      end

      it 'generates stable UUIDs for native targets and its product references' do
        Digest('MD5').expects(:hexdigest).with('Project.xcodeprojNativeTarget1').returns('CLEANSOAP')
        Digest('MD5').expects(:hexdigest).with('Project.xcodeprojproduct_referenceNativeTarget1').returns('CLEANSOAP')

        @target_uuid_generator.generate!
        @project.targets.each do |target|
          target.uuid.should.equal 'CLEANSOAP'
          target.product_reference.uuid.should.equal 'CLEANSOAP'
        end
      end
    end
  end
end
