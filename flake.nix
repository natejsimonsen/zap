{
  description = "Zap — a minimal macOS application launcher bound to Cmd+Space";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAll (pkgs: {
        default = pkgs.stdenv.mkDerivation {
          pname = "zap";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.swift pkgs.swiftpm pkgs.darwin.sigtool ];

          # `strip` invalidates the linker's ad-hoc code signature, which makes
          # launchd kill the binary with OS_REASON_CODESIGNING. Keep the binary
          # unstripped and re-sign ad-hoc in postInstall (mirrors build.sh).
          dontStrip = true;
          # The modern nixpkgs Apple SDK (14) provides SwiftUI/AppKit/Carbon
          # headers and frameworks this app needs (macOS 14 APIs).
          buildInputs = [ pkgs.apple-sdk_14 ];

          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR"
            swift build -c release --disable-sandbox
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            appdir="$out/Applications/Zap.app"
            mkdir -p "$appdir/Contents/MacOS" "$appdir/Contents/Resources" "$out/bin"
            cp .build/release/Zap "$appdir/Contents/MacOS/Zap"
            cat > "$appdir/Contents/Info.plist" <<EOF
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundleName</key><string>Zap</string>
              <key>CFBundleDisplayName</key><string>Zap</string>
              <key>CFBundleIdentifier</key><string>com.local.zap</string>
              <key>CFBundleVersion</key><string>0.1.0</string>
              <key>CFBundleShortVersionString</key><string>0.1.0</string>
              <key>CFBundlePackageType</key><string>APPL</string>
              <key>CFBundleExecutable</key><string>Zap</string>
              <key>LSMinimumSystemVersion</key><string>14.0</string>
              <key>LSUIElement</key><true/>
              <key>NSHighResolutionCapable</key><true/>
            </dict>
            </plist>
            EOF
            ln -s "$appdir/Contents/MacOS/Zap" "$out/bin/zap"

            # Ship the login-item installer so `flox install` users can enable
            # autostart with one command: `zap-autostart`.
            install -m 0755 contrib/install-login-item.sh "$out/bin/zap-autostart"
            install -m 0755 contrib/uninstall-login-item.sh "$out/bin/zap-autostart-off"

            # Fresh ad-hoc signature so launchd/Gatekeeper accept the binary.
            codesign --force --sign - "$appdir/Contents/MacOS/Zap"
            runHook postInstall
          '';

          meta = {
            description = "Minimal macOS application launcher bound to Cmd+Space";
            homepage = "https://github.com/natejsimonsen/zap";
            license = nixpkgs.lib.licenses.mit;
            platforms = systems;
            mainProgram = "zap";
          };
        };
      });

      apps = forAll (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/zap";
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.swift ];
          inputsFrom = [ self.packages.${pkgs.system}.default ];
        };
      });
    };
}
