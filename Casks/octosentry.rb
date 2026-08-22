# Homebrew Cask for octosentry (spec §9: DMG/Homebrew distribution channel).
#
# Canonical copy lives in krazywarez/homebrew-tap — this one is kept in sync
# here for reference. Users install via:
#   brew tap krazywarez/tap && brew install --cask octosentry

cask "octosentry" do
  version "1.1"
  sha256 "8f53ce0c4810d6590f8095e983da53a5afc3938ac94333bdb1d9846bb86ec48a"

  url "https://github.com/krazywarez/octosentry/releases/download/#{version}/octosentry-#{version}.dmg"
  name "octosentry"
  desc "Menu bar app aggregating GitHub security alerts into one feed"
  homepage "https://github.com/krazywarez/octosentry"

  depends_on macos: :sonoma

  app "octosentry.app"

  zap trash: [
    "~/Library/Application Support/octosentry",
  ]
end
