## 0.3.0

### Multiple targets

Add support for multiple static library targets in the Pods Xcode project with
different sets of depedencies. This means that you can create a separate
library which contains all dependencies, including extra ones that you only use
in, for instance, a debug or test build. [[docs][1]]

```Ruby
# This Podfile will build three static libraries:
# * libPods.a
# * libPods-debug.a
# * libPods-test.a

# This dependency is included in the `default` target, which generates the
# `libPods.a` library, and all non-exclusive targets.
dependency 'SSCatalog'

target :debug do
  # This dependency is only included in the `debug` target, which generates
  # the `libPods-debug.a` library.
  dependency 'CocoaLumberjack'
end

target :test, :exclusive => true do
  # This dependency is *only* included in the `test` target, which generates
  # the `libPods-test.a` library.
  dependency 'Kiwi'
end
```

### Install libraries from anywhere

A dependency can take a git url if the repo contains a podspec file in its
root, or a podspec can be loaded from a file or HTTP location. If no podspec is
available, a specification can be defined inline in the Podfile. [[docs][2]]

```Ruby
# From a spec repo.
dependency 'SSToolkit'

# Directly from the Pod’s repo (if it contains a podspec).
dependency 'SSToolkit', :git => 'https://github.com/samsoffes/sstoolkit.git'

# Directly from the Pod’s repo (if it contains a podspec) with a specific commit (or tag).
dependency 'SSToolkit', :git    => 'https://github.com/samsoffes/sstoolkit.git',
                        :commit => '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b'

# From a podspec that's outside a spec repo _and_ the library’s repo. This can be a file or http url.
dependency 'SSToolkit', :podspec => 'https://raw.github.com/gist/1353347/ef1800da9c5f5d267a642b8d3950b41174f2a6d7/SSToolkit-0.1.1.podspec'

# If no podspec is available anywhere, you can define one right in your Podfile.
dependency do |s|
  s.name         = 'SSToolkit'
  s.version      = '0.1.3'
  s.platform     = :ios
  s.source       = { :git => 'https://github.com/samsoffes/sstoolkit.git', :commit => '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b' }
  s.resources    = 'Resources'
  s.source_files = 'SSToolkit/**/*.{h,m}'
  s.frameworks   = 'QuartzCore', 'CoreGraphics'

  def s.post_install(target)
    prefix_header = config.project_pods_root + target.prefix_header_filename
    prefix_header.open('a') do |file|
      file.puts(%{#ifdef __OBJC__\n#import "SSToolkitDefines.h"\n#endif})
    end
  end
end
```

### Add a `post_install` hook to the Podfile class

This allows the user to customize, for instance, the generated Xcode project
_before_ it’s written to disk. [[docs][3]]

```Ruby
# Enable garbage collection support for MacRuby applications.
post_install do |installer|
  installer.project.targets.each do |target|
    target.buildConfigurations.each do |config|
      config.buildSettings['GCC_ENABLE_OBJC_GC'] = 'supported'
    end
  end
end
```

### Manifest

Generate a Podfile.lock file next to the Podfile, which contains a manifest of
your application’s dependencies and their dependencies.

```
PODS:
  - JSONKit (1.4)
  - LibComponentLogging-Core (1.1.4)
  - LibComponentLogging-NSLog (1.0.2):
    - LibComponentLogging-Core (>= 1.1.4)
  - RestKit-JSON-JSONKit (0.9.3):
    - JSONKit
    - RestKit (= 0.9.3)
  - RestKit-Network (0.9.3):
    - LibComponentLogging-NSLog
    - RestKit (= 0.9.3)
  - RestKit-ObjectMapping (0.9.3):
    - RestKit (= 0.9.3)
    - RestKit-Network (= 0.9.3)

DOWNLOAD_ONLY:
  - RestKit (0.9.3)

DEPENDENCIES:
  - RestKit-JSON-JSONKit
  - RestKit-ObjectMapping
```

### Generate Xcode projects from scratch

We no longer ship template projects with the gem, but instead generate them
programmatically. This code has moved out into its own [Xcodeproj gem][4],
allowing you to automate Xcode related tasks.




[1]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L151
[2]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L82
[3]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L185
[4]: https://github.com/CocoaPods/Xcodeproj
