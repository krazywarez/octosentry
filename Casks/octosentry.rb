# Homebrew Cask for octosentry (spec §9: DMG/Homebrew distribution channel).
#
# Mirrored between krazywarez/octosentry and krazywarez/homebrew-tap. The tap's
# copy is the one `brew install` reads; keep both in sync. Users install via:
#   brew tap krazywarez/tap && brew install --cask octosentry

cask "octosentry" do
  version "1.1.1"
  sha256 "54abd231f8805af9a75a62ce60f065e492d4447f0387d4505d23ab1ade3dabbc"

  url "https://github.com/krazywarez/octosentry/releases/download/#{version}/octosentry-#{version}.dmg"
  name "octosentry"
  desc "Menu bar app aggregating GitHub security alerts into one feed"
  homepage "https://github.com/krazywarez/octosentry"

  depends_on macos: :sonoma

  app "octosentry.app"

  zap trash: "~/Library/Application Support/octosentry"
end
