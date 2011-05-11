#!/bin/sh
ant debug -quiet || exit 1
adb -d install -r bin/RaumZeitStatus-debug.apk || exit 1
#adb shell am start -a android.intent.action.MAIN -n org.raumzeitlabor.status/.main

# to release:
#
# ant release
# jarsigner -verbose -keystore ~/.keystore-rzlstatus bin/RaumZeitStatus-unsigned.apk mykey
# zipalign -v 4 bin/RaumZeitStatus-unsigned.apk bin/RaumZeitStatus.apk
