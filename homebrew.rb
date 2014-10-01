# Homebrew
# -----

require "rake/packagetask"

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

GEMS_DIR = "vendor/gems"
GH_PAGES_DIR = "gh-pages"
HOMEBREW_FORMULAE_DIR = "homebrew-formulae"

namespace :gems do
  desc "Vendorize dependencies"
  task :vendorize do
    system("vendor/vendorize", GEMS_DIR)
  end

  desc "Remove vendorized dependencies"
  task :clean do
    FileUtils.rm_r(GEMS_DIR) if Dir.exist?(GEMS_DIR)
  end
end

desc "Push new release"
task homebrewrelease: ["release:build", "release:push", "release:clean"]

namespace :release do
  desc "Build a new release"
  task build: ["tarball:build", "homebrew:build"]

  desc "Push sub-repositories"
  task push: ["tarball:push", "homebrew:push"]

  desc "Clean all build artifacts"
  task clean: ["gems:clean", "tarball:clean", "homebrew:clean"]
end

namespace :homebrew do
  desc "Generate homebrew formula and add it to the repo"
  task build: ["checkout", "formula:build", "commit"]

  desc "Checkout homebrew repo locally"
  task :checkout do
    `git clone https://github.com/Keithbsmiley/homebrew-formulae.git #{ HOMEBREW_FORMULAE_DIR }`
  end

  desc "Check in the new Homebrew formula"
  task :commit do
    Dir.chdir(HOMEBREW_FORMULAE_DIR) do
      `git add Formula/cocoapods.rb`
      `git commit -m "cocoapods: Release version #{ gem_version }"`
    end
  end

  desc "Push homebrew repo"
  task :push do
    Dir.chdir(HOMEBREW_FORMULAE_DIR) do
      `git push`
    end
  end

  desc "Remove Homebrew repo"
  task :clean do
    FileUtils.rm_rf(HOMEBREW_FORMULAE_DIR) if Dir.exist?(HOMEBREW_FORMULAE_DIR)
  end

  namespace :formula do
    desc "Build homebrew formula"
    task :build do
      formula = File.read("homebrew/cocoapods.rb")
      formula.gsub!("__VERSION__", gem_version)
      formula.gsub!(
        "__SHA__",
        `shasum #{ GH_PAGES_DIR }/cocoapods-#{ gem_version }.tar.gz`
          .split.first)
      File.write("#{ HOMEBREW_FORMULAE_DIR }/Formula/cocoapods.rb", formula)
    end
  end
end

namespace :tarball do
  desc "Build the tarball"
  task build: ["checkout", "package", "move", "commit"]

  desc "Checkout gh-pages"
  task :checkout do
    `git clone --branch gh-pages https://github.com/Keithbsmiley/cocoapods.git #{ GH_PAGES_DIR }`
  end

  desc "Move tarball into gh-pages"
  task :move do
    FileUtils.mv("pkg/cocoapods-#{ gem_version }.tar.gz", GH_PAGES_DIR)
  end

  desc "Check in the new tarball"
  task :commit do
    Dir.chdir(GH_PAGES_DIR) do
      `git add cocoapods-#{ gem_version }.tar.gz`
      `git commit -m "Release version #{ gem_version }"`
    end
  end

  desc "Push the gh-pages branch"
  task :push do
    Dir.chdir(GH_PAGES_DIR) do
      `git push`
    end
  end

  desc "Remove gh-pages and pkg directories"
  task :clean do
    FileUtils.rm_rf(GH_PAGES_DIR) if Dir.exist?(GH_PAGES_DIR)
    FileUtils.rm_rf("pkg") if Dir.exist?("pkg")
  end

  # :package task
  Rake::PackageTask.new("cocoapods", gem_version) do |p|
    p.need_tar_gz = true
    p.package_files.include("src/**/*")
    p.package_files.include("lib/**/*")
    p.package_files.include("vendor/**/*")
    p.package_files.include("LICENSE")
  end
end
