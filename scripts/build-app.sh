#!/bin/zsh
# Builds a universal (Apple silicon + Intel) Netbar.app into ./build.
#   --install   also copy it to ~/Applications
#   --zip       also write build/Netbar-<version>.zip for a GitHub release
#   --notarize  notarize the app with Apple and staple the ticket before zipping (implies --zip)
#   --pkg       also write build/Netbar-<version>.pkg, an installer package (notarized too
#               with --notarize); needs INSTALLER_IDENTITY, a "Developer ID Installer: …" certificate
#
# Signing is ad-hoc by default, which is enough to run it on your own Mac. For a release,
# set SIGN_IDENTITY to a "Developer ID Application: …" certificate in your keychain and,
# for --notarize, NOTARY_PROFILE to credentials saved with `xcrun notarytool store-credentials`.
set -euo pipefail

root="${0:A:h:h}"
app="$root/build/Netbar.app"

install=false zip=false notarize=false pkg=false
for flag in "$@"; do
  case "$flag" in
    --install) install=true ;;
    --zip) zip=true ;;
    --notarize) notarize=true zip=true ;;
    --pkg) pkg=true ;;
    *)
      echo "Unknown option $flag" >&2
      exit 2
      ;;
  esac
done
if $notarize && [[ -z "${SIGN_IDENTITY:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
  echo "--notarize needs SIGN_IDENTITY and NOTARY_PROFILE" >&2
  exit 2
fi
if $pkg && [[ -z "${INSTALLER_IDENTITY:-}" ]]; then
  echo "--pkg needs INSTALLER_IDENTITY" >&2
  exit 2
fi

# Builds <product> once per architecture and merges the slices with lipo, printing the
# universal binary's path. `swift build --arch arm64 --arch x86_64` would need Xcode's
# build system; this also works with just the Command Line Tools.
universal() {
  local product=$1 slices=() arch
  for arch in arm64 x86_64; do
    local triple="$arch-apple-macosx14.0"
    swift build --package-path "$root" -c release --triple "$triple" --product "$product" >&2
    slices+=("$(swift build --package-path "$root" -c release --triple "$triple" --show-bin-path)/$product")
  done
  mkdir -p "$root/build/universal"
  lipo -create "${slices[@]}" -output "$root/build/universal/$product"
  echo "$root/build/universal/$product"
}

netbar_bin="$(universal Netbar)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$netbar_bin" "$app/Contents/MacOS/Netbar"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"

# App icon from assets/icon.svg
work="$(mktemp -d)"
qlmanage -t -s 1024 -o "$work" "$root/assets/icon.svg" >/dev/null 2>&1
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$work/icon.svg.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$work/icon.svg.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
rm -rf "$work"

# Developer ID signatures get the hardened runtime and a secure timestamp, which
# notarization requires.
identity="${SIGN_IDENTITY:--}"
sign=(codesign --force --sign "$identity")
[[ "$identity" != "-" ]] && sign+=(--options runtime --timestamp)
"${sign[@]}" "$app"
codesign --verify --strict "$app"
echo "Built $app ($(lipo -archs "$app/Contents/MacOS/Netbar"), signed with ${SIGN_IDENTITY:-an ad-hoc signature})"

if $zip; then
  version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
  archive="$root/build/Netbar-$version.zip"
  rm -f "$archive"
  ditto -c -k --keepParent "$app" "$archive"
  if $notarize; then
    echo "Submitting to Apple for notarization (usually a few minutes)…"
    xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
    # Attach the ticket to the app so it opens offline too, then zip it again.
    xcrun stapler staple "$app"
    spctl --assess --type execute --verbose=2 "$app"
    rm -f "$archive"
    ditto -c -k --keepParent "$app" "$archive"
  fi
  echo "Wrote $archive"
  # Values for Casks/netbar.rb in github.com/Kombuchelada/homebrew-tap,
  # after uploading this zip to the v$version release.
  echo "Cask: version \"$version\""
  echo "      sha256 \"$(shasum -a 256 "$archive" | cut -d' ' -f1)\""
fi

if $pkg; then
  if $notarize; then
    "$root/scripts/make-pkg.sh" "$app"
  else
    NOTARY_PROFILE= "$root/scripts/make-pkg.sh" "$app"
  fi
fi

if $install; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Netbar.app"
  cp -R "$app" "$HOME/Applications/"
  echo "Installed to $HOME/Applications/Netbar.app"
fi
