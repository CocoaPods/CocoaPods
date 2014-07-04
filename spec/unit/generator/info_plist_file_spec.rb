require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::InfoPlistFile do

  it 'generates a valid Info.plist file' do
    generator = Pod::Generator::InfoPlistFile.new(mock('Target'))
    file = temporary_directory + 'Info.plist'
    generator.save_as(file)
    `plutil -lint #{file}`
    $?.should.be.success
  end

end
