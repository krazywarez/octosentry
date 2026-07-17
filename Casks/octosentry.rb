# Homebrew Cask for octosentry (spec §9: DMG/Homebrew distribution channel).
#
# This file lives here as a template — Homebrew taps must be their own repo
# named "homebrew-<tapname>" for `brew tap` to find them. To actually publish:
#   1. Create github.com/zerolabsco/homebrew-tap (or similar)
#   2. Copy this file there as Casks/octosentry.rb
#   3. Fill in sha256 below with the real checksum of the released DMG:
#        shasum -a 256 octosentry-<version>.dmg
#   4. Users install via: brew tap zerolabsco/tap && brew install --cask octosentry

cask "octosentry" do
  version "1.0.0"
  sha256 "REPLACE_WITH_REAL_SHA256_OF_RELEASED_DMG"

  url "https://github.com/zerolabsco/octosentry/releases/download/#{version}/octosentry-#{version}.dmg"
  name "octosentry"
  desc "Menu bar app aggregating GitHub security alerts into one feed"
  homepage "https://github.com/zerolabsco/octosentry"

  depends_on macos: ">= :sonoma"

  app "octosentry.app"

  zap trash: [
    "~/Library/Application Support/octosentry",
  ]
end
