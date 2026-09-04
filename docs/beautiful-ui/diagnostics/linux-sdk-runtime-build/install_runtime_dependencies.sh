#!/bin/sh
set -eu
apt-get update
apt-get install -y --no-install-recommends \
  orca speech-dispatcher speech-dispatcher-espeak-ng espeak-ng \
  pulseaudio pulseaudio-utils python3-gi python3-pyatspi python3-speechd \
  gir1.2-gtk-3.0 at-spi2-core dbus-x11 xvfb xauth xdotool \
  libgl1-mesa-dri mesa-utils
