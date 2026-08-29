cask "zap" do
  version "0.3.0"
  sha256 "db272f5cf31db47e1971dedcee02b2c64ff259df972e87e349044cce7078d61a"

  url "https://github.com/natejsimonsen/zap/releases/download/v#{version}/Zap.zip"
  name "Zap"
  desc "Minimal macOS application launcher bound to Cmd+Space"
  homepage "https://github.com/natejsimonsen/zap"

  app "Zap.app"

  caveats <<~EOS
    Zap is not notarized, so on first launch macOS Gatekeeper may block it.
    Either right-click Zap.app in /Applications and choose Open, or run:

      xattr -dr com.apple.quarantine "#{appdir}/Zap.app"

    Then free up the hotkey: System Settings > Keyboard > Keyboard Shortcuts >
    Spotlight, and uncheck "Show Spotlight search" (Cmd+Space).
  EOS
end
