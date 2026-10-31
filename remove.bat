@echo off
echo "Please make sure you have used a temporary root exploit, as this requires that. Exploits have not been bundled, but you can look over XDA Forums for exploits! (Tested on Fire 7 2022, quartz)"
echo "Pushing exploit to device..."
adb push data/remove-parentalcontrols.sh /data/local/tmp
echo "Running exploit as root..."
adb shell su -c /data/local/tmp/remove-parentalcontrols.sh