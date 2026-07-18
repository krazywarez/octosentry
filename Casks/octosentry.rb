# Homebrew Cask for octosentry (spec §9: DMG/Homebrew distribution channel).
#
# Canonical copy lives in zerolabsco/homebrew-tap — this one is kept in sync
# here for reference. Users install via:
#   brew tap zerolabsco/tap && brew install --cask octosentry

cask "octosentry" do
  version "1.0.0"
  sha256 "33c5b89ce817d5be7bacc8d6fe5e2ff5678b071e50eba0270ef31de32fc4566a"

  url "https://github.com/zerolabsco/octosentry/releases/download/#{version}/octosentry-#{version}.dmg"
  name "octosentry"
  desc "Menu bar app aggregating GitHub security alerts into one feed"
  homepage "https://github.com/zerolabsco/octosentry"

  depends_on macos: :sonoma

  app "octosentry.app"

  zap trash: [
    "~/Library/Application Support/octosentry",
  ]
end
