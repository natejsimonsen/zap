cask "zap" do
  version "0.5.0"
  sha256 "e586627d814557a9081b56ed1186d91194b35f3bad3fee1fa5f85466b5eb5d3b"

  url "https://github.com/natejsimonsen/zap/releases/download/v#{version}/Zap.zip"
  name "Zap"
  desc "Minimal macOS application launcher bound to Cmd+Space"
  homepage "https://github.com/natejsimonsen/zap"

  app "Zap.app"
  binary "#{appdir}/Zap.app/Contents/MacOS/Zap", target: "zap"

  caveats <<~EOS
    Zap is not notarized, so on first launch macOS Gatekeeper may block it.
    Either right-click Zap.app in /Applications and choose Open, or run:

      xattr -dr com.apple.quarantine "#{appdir}/Zap.app"

    Then free up the hotkey: System Settings > Keyboard > Keyboard Shortcuts >
    Spotlight, and uncheck "Show Spotlight search" (Cmd+Space).
  EOS
end
