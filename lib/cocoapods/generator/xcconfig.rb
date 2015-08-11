module Pod
  module Generator
    # Generates Xcode configuration files. A configuration file is generated
    # for each Pod and for each Pod target definition. The aggregates the
    # configurations of the Pods and define target specific settings.
    #
    module XCConfig
      autoload :AggregateXCConfig,  'cocoapods/generator/xcconfig/aggregate_xcconfig'
      autoload :PodXCConfig,        'cocoapods/generator/xcconfig/pod_xcconfig'
      autoload :XCConfigHelper,     'cocoapods/generator/xcconfig/xcconfig_helper'
    end
  end
end
