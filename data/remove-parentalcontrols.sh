#!/system/bin/sh
# remove-parentalcontrols.sh
#
# Removes com.amazon.parentalcontrols on a rooted Fire 7 (Fire OS 8 / Android 11
# base) by blocking its boot receiver via the Intent Firewall, clearing its
# device-admin / profile-owner registration, and uninstalling it for user 0.
#
# Run this FROM a root shell ON THE DEVICE (e.g. `adb shell`, then `su`, then
# this script; or paste directly into a root terminal app on-device).
#
# Does not touch /system. Does not trigger AVB/dm-verity. Fully reversible via
# the backups this script makes in /sdcard/dpbak, or a factory reset.
#
# Tested on: Fire 7, Fire OS 8. Component names were read from dumpsys/logcat
# on that build - verify against `dumpsys device_policy` on your own device
# before running, in case Amazon renamed classes on a different Fire OS version.

set -e

PKG="com.amazon.parentalcontrols"
RECEIVER="com.amazon.parentalcontrols/com.amazon.parentalcontrols.receivers.ParentalBootBroadcastReceiver"
POLICY_FILE="/data/system/device_policies.xml"
OWNER_FILE="/data/system/users/0/profile_owner.xml"
IFW_DIR="/data/system/ifw"
IFW_FILE="$IFW_DIR/parentalcontrols.xml"
BACKUP_DIR="/sdcard/dpbak"

echo "== remove-parentalcontrols.sh =="

if [ "$(id -u)" != "0" ]; then
  echo "ERROR: must be run as root (got uid $(id -u)). Run 'su' first."
  exit 1
fi

echo "[1/7] Checking current state..."
dumpsys device_policy | grep -i parentalcontrols && FOUND=1 || FOUND=0
if [ "$FOUND" = "0" ]; then
  echo "No profile owner / admin registration found for $PKG."
  echo "It may already be cleared. Attempting uninstall directly..."
  pm uninstall -k --user 0 "$PKG" || echo "Uninstall failed or already removed."
  exit 0
fi

echo "[2/7] Backing up current policy files to $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
[ -f "$OWNER_FILE" ] && cp "$OWNER_FILE" "$BACKUP_DIR/" || echo "  (no profile_owner.xml to back up)"
[ -f "$POLICY_FILE" ] && cp "$POLICY_FILE" "$BACKUP_DIR/" || echo "  (no device_policies.xml to back up)"
ls -l "$BACKUP_DIR"

echo "[3/7] Checking file format (should start with '<?xm', not 'ABX')..."
head -c 4 "$POLICY_FILE"; echo
if [ "$(head -c 3 "$POLICY_FILE")" = "ABX" ]; then
  echo "ERROR: $POLICY_FILE is Android Binary XML, not plain text."
  echo "This script only handles plain-text XML. Stopping without changes."
  exit 1
fi

echo "[4/7] Installing Intent Firewall rule to block the boot receiver..."
mkdir -p "$IFW_DIR"
cat > "$IFW_FILE" << EOF
<rules>
<broadcast>
<block>
<component-filter name="$RECEIVER" />
</block>
</broadcast>
</rules>
EOF
chown system:system "$IFW_DIR" "$IFW_FILE"
chmod 755 "$IFW_DIR"
chmod 644 "$IFW_FILE"
echo "  Rule written to $IFW_FILE"

echo "[5/7] Clearing device-admin and profile-owner records..."
printf '%s\n' "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" \
  '<policies setup-complete="true">' \
  '<password-validity value="true" />' \
  '<lock-task-features value="16" />' \
  '</policies>' > "$POLICY_FILE"
rm -f "$OWNER_FILE"
sync
echo "  device_policies.xml now:"
cat "$POLICY_FILE"
echo "  profile_owner.xml exists?"; ls "$OWNER_FILE" 2>&1 || true

echo "[6/7] Restarting system_server to apply changes..."
echo "  (screen will go black for ~30-60s, this is expected)"
kill -9 "$(pidof system_server)"
sleep 45

echo "[7/7] Verifying and uninstalling..."
dumpsys device_policy | grep -i parentalcontrols && STILL=1 || STILL=0
if [ "$STILL" = "1" ]; then
  echo "WARNING: $PKG still shows as profile owner / admin after restart."
  echo "The IFW rule may not match this device's receiver name, or there is"
  echo "another trigger besides BOOT_COMPLETED. Not uninstalling automatically."
  echo "Compare the component name above against:"
  echo "  dumpsys package $PKG | grep -B2 -A8 'Receiver Resolver Table'"
  exit 1
fi

pm uninstall -k --user 0 "$PKG"
echo "Done. Cleaning up IFW rule (no longer needed)..."
rm -rf "$IFW_DIR"
echo "Complete. Backups remain in $BACKUP_DIR if you ever need to restore."
