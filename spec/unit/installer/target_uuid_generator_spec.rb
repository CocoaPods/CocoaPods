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

      it 'does not hand out UUIDs of existing objects to objects created afterwards' do
        @target_uuid_generator.generate!
        existing = @project.objects_by_uuid.keys
        new_uuids = Array.new(101) { |i| @project.main_group.new_group("group-#{i}").uuid }
        (new_uuids & existing).should.be.empty
        new_uuids.uniq.size.should == new_uuids.size
        @project.objects_by_uuid[@project.root_object.uuid].should.equal @project.root_object
      end
    end
  end
end
