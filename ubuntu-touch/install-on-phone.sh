#!/bin/sh
# Builds Revell T.V on the Ubuntu Touch phone connected by USB (developer mode on),
# installs it the way the OpenStore does, and opens it. Usage: ./install-on-phone.sh
set -e
cd "$(dirname "$0")"
ADB=$(command -v adb || echo "$HOME/.local/opt/platform-tools/adb")
VERSION=$(sed -n 's/.*"version": "\(.*\)".*/\1/p' manifest.json)
CLICK="revell-tv.harmoney1111_${VERSION}_all.click"
BUILD=/home/phablet/revell-tv-build

"$ADB" shell "rm -rf $BUILD && mkdir -p $BUILD/src"
"$ADB" push manifest.json revell-tv.apparmor revell-tv.desktop qml assets "$BUILD/src/" >/dev/null
"$ADB" shell "export XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus
  cd $BUILD && click build src >/dev/null &&
  lomiri-app-stop revell-tv.harmoney1111_revell-tv 2>/dev/null
  busctl --system call --timeout=120 com.lomiri.click /com/lomiri/click com.lomiri.click Install s $BUILD/$CLICK &&
  rm -rf $BUILD &&
  click list | grep revell-tv &&
  lomiri-app-launch revell-tv.harmoney1111_revell-tv_$VERSION"
