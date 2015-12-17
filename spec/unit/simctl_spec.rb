require File.expand_path('../../spec_helper', __FILE__)

module Pod
  SIMCTL_OUTPUT = <<-EOF
-- iOS 9.2 --
    iPhone 4s (C0404A23-2D2D-4208-8CEC-774194D06759) (Shutdown)
    iPhone 5 (7A0F62DD-8330-44F0-9828-AC8B1BC9BF05) (Shutdown)
    iPhone 5s (51C1CB50-FBCB-47ED-B8FF-68C816BF0932) (Shutdown)
    iPhone 6 (6F4E143A-6914-476E-90BF-51B680B8E2EF) (Shutdown)
    iPhone 6 Plus (BEB9BFE9-AF1A-4FEA-9FA5-CAFD5243CA42) (Shutdown)
    iPhone 6s (98DB904B-DF98-4F3C-AB21-A4D133604BA4) (Shutdown)
    iPhone 6s Plus (65838307-4C03-4DD3-84E4-A6477CFD3490) (Shutdown)
    iPad 2 (349C1313-6C9C-48C6-8849-DAB18BE2F15C) (Shutdown)
    iPad Retina (30909168-4C90-48CD-B142-86DCF7B1372A) (Shutdown)
    iPad Air (A8B5F651-C215-459C-95C6-663194F2277B) (Shutdown)
    iPad Air 2 (BFDB363E-D514-490C-A1D6-AC86402089BA) (Shutdown)
    iPad Pro (AE5DA548-66F6-4FCE-AA6D-5E6E17CD721E) (Shutdown)
-- tvOS 9.1 --
    Apple TV 1080p (C5A44868-685C-4D72-BEBD-102246C870F7) (Shutdown)
-- watchOS 2.1 --
    Apple Watch - 38mm (FE557B65-A044-44C3-96AC-2EAC395A6090) (Shutdown)
    Apple Watch - 42mm (C9138FAE-6812-4BB5-A463-76520C116AF4) (Shutdown)
EOF

  describe SimControl do
    describe 'In general' do
      before do
        @ctrl = SimControl.new
        @ctrl.stubs(:list).returns(SIMCTL_OUTPUT)
      end

      it 'can find all usable simulators' do
        sims = @ctrl.usable_simulators
        sims.count.should == 15
      end

      it 'can find a specific simulator' do
        sim = @ctrl.simulator('iPhone 4s')

        sim.id.should == 'C0404A23-2D2D-4208-8CEC-774194D06759'
        sim.name.should == 'iPhone 4s'
        sim.os_name.should == 'iOS'
        sim.os_version.should == '9.2'
      end

      it 'can construct the destination argument for a specific simulator' do
        destination = @ctrl.destination('iPhone 4s')

        destination.should == ['-destination', 'id=C0404A23-2D2D-4208-8CEC-774194D06759']
      end
    end
  end

  describe Simulator do
    describe 'In general' do
      it 'can parse a line of simctl output' do
        line = SIMCTL_OUTPUT.lines[1]
        sim = Simulator.match(line, 'iOS', '8.0').first

        sim.id.should == 'C0404A23-2D2D-4208-8CEC-774194D06759'
        sim.name.should == 'iPhone 4s'
        sim.os_name.should == 'iOS'
        sim.os_version.should == '8.0'
      end

      it 'returns an empty list on invalid input' do
        sim = Simulator.match('¯\_(ツ)_/¯', 'iOS', '8.0')

        sim.should == []
      end

      it 'has a meaningful string conversion' do
        line = SIMCTL_OUTPUT.lines[1]
        sim = Simulator.match(line, 'iOS', '8.0')

        sim.first.to_s.should == 'iPhone 4s (C0404A23-2D2D-4208-8CEC-774194D06759) - iOS 8.0'
      end
    end
  end
end
