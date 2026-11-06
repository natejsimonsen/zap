cask "zap" do
  version "0.4.0"
  sha256 "1473e1f9f24b1afc3e287622c8cdf6ef4cde1074b5545b6dfe702b957f1c758e"

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
