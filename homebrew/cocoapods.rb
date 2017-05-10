require "formula"

class Cocoapods < Formula
  homepage "https://github.com/CocoaPods/cocoapods/"
  url "http://CocoaPods.github.io/CocoaPods/cocoapods-__VERSION__.tar.gz"
  sha1 "__SHA__"

  depends_on "xcproj" => :recommended

  def install
    prefix.install "vendor"
    prefix.install "lib" => "rubylib"

    bin.install "src/pod"
  end

  test do
    system "#{bin}/cocoapods", "--version"
  end
end
