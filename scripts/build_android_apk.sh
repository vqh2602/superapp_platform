#!/bin/bash
cd "$(dirname "$0")" || exit 1

if [ ! -z "$1" ]
then
  app_name="$1"
  echo "Build apk ứng dụng $app_name"
  if [ -d "./.android" ]; then
    cp -r ./.android/* ../android 2>/dev/null || true
  fi
  cd .. && flutter build apk --flavor $app_name -t lib/main_$app_name.dart
else
  echo "Build apk ứng dụng main"
  cd .. && flutter build apk -t lib/main.dart
fi
