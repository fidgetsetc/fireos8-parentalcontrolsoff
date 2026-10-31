This is a summarization made by Claude of how we got this working.

# Removing `com.amazon.parentalcontrols` on a rooted Fire 7 (Fire OS 8)

## Summary

`com.amazon.parentalcontrols` registers itself as both a **device admin** and the **profile owner for user 0** on boot. Android blocks `pm uninstall`, `pm disable-user`, and `pm disable` (even per-component) against any package that currently holds profile-owner status — this is deliberate anti-tamper behavior, not a bug. The app also re-registers itself on every boot via a `BOOT_COMPLETED` receiver, so simply clearing the policy files and rebooting doesn't work: the app just re-claims profile owner before you get a chance to uninstall it.

As a side effect, with no profile owner registered, Android no longer reports a managed work profile on the device at all. Several apps that check `DevicePolicyManager` at launch (observed: Gemini, ChatGPT) behaved differently / worked afterward, likely because they refuse to run or restrict themselves on devices they detect as "managed."

Tested on: Fire 7, Fire OS 8 (Android 11 base), temporary root.

**This requires root.** It does not touch `/system` or trigger AVB/dm-verity — everything happens under `/data`, which isn't covered by Android Verified Boot.

## Why the obvious approaches fail

- `pm uninstall -k --user 0 com.amazon.parentalcontrols` → fails, app is profile owner.
- `pm disable-user --user 0 com.amazon.parentalcontrols` → `SecurityException: Cannot disable a protected package`.
- `pm disable --user 0 com.amazon.parentalcontrols/.receivers.ParentalBootBroadcastReceiver` (component-level) → same `SecurityException`. The protected-package check applies at the component level too, not just the whole package.
- Manually clearing `/data/system/device_policies.xml` and `/data/system/users/0/profile_owner.xml`, then doing a **normal `reboot`** → doesn't stick. The app's boot receiver fires during the same boot and re-registers itself as profile owner before you can act.
- Killing `system_server` with `kill -9` instead of a clean reboot → also doesn't stick, for the same reason (it still goes through a normal boot sequence and the receiver still fires).

## Root cause (confirmed via logcat)

```
ActivityManager: Start proc ####:com.amazon.parentalcontrols/u0a100 for broadcast
  {com.amazon.parentalcontrols/com.amazon.parentalcontrols.receivers.ParentalBootBroadcastReceiver}
AmznDevicePolicyManager: setProfileOwnerComponent is redundant - Use DevicePolicyManager#setProfileOwner instead
DevicePolicyManager: Profile owner set: ComponentInfo{com.amazon.parentalcontrols/...ParentalAdminReceiver} on user 0
```

The app's own `ParentalBootBroadcastReceiver`, triggered by `android.intent.action.BOOT_COMPLETED`, calls into Amazon's device policy manager and re-asserts itself as profile owner within ~8ms of starting. This happens on every boot, including a `system_server`-only restart (which still re-sends `BOOT_COMPLETED` to not-yet-notified receivers).

## The fix: block the boot receiver with the Intent Firewall

Android's Intent Firewall (IFW) reads rule files from `/data/system/ifw/` at startup and can block specific broadcasts to specific components. This is enforced independently of the protected-package check that blocks `pm enable`/`disable`, so it isn't subject to the same `SecurityException`.

```sh
mkdir -p /data/system/ifw && cat > /data/system/ifw/parentalcontrols.xml << 'EOF'
<rules>
<broadcast>
<block>
<component-filter name="com.amazon.parentalcontrols/com.amazon.parentalcontrols.receivers.ParentalBootBroadcastReceiver" />
</block>
</broadcast>
</rules>
EOF
chown system:system /data/system/ifw /data/system/ifw/parentalcontrols.xml
chmod 755 /data/system/ifw
chmod 644 /data/system/ifw/parentalcontrols.xml
```

With the boot receiver blocked, clear the existing policy state and force a hard restart of the framework (not a full device reboot — a `system_server` kill is enough and faster to iterate on):

```sh
printf '%s\n' "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" \
  '<policies setup-complete="true">' \
  '<password-validity value="true" />' \
  '<lock-task-features value="16" />' \
  '</policies>' > /data/system/device_policies.xml

rm -f /data/system/users/0/profile_owner.xml
sync
kill -9 $(pidof system_server)
```

> Note: `/data/system/device_policies.xml` holds the device-admin list (per-device, not per-user, despite living alongside per-user files). `/data/system/users/0/profile_owner.xml` holds the profile owner record for user 0 specifically. Both needed to be cleared — removing only one left the other able to partially reassert state.

After the framework restarts (device will be unresponsive for 30–60s), verify:

```sh
dumpsys device_policy | grep -i parentalcontrols
```

Empty output confirms both the admin and profile-owner records are gone and nothing re-registered them. Then the uninstall goes through normally:

```sh
pm uninstall -k --user 0 com.amazon.parentalcontrols
```

Once removed, the IFW rule is inert and can be cleaned up:

```sh
rm -rf /data/system/ifw
```

## Diagnostic commands used along the way

Finding the admin/profile-owner registration and its policies:
```sh
dumpsys device_policy | grep -i -B2 -A6 parentalcontrols
```

Checking file format before editing (should be plain XML, not Android Binary XML — if it starts with `ABX` do not hand-edit it):
```sh
head -c 4 /data/system/device_policies.xml
```

Tracing what re-registers the profile owner after a clean restart:
```sh
logcat -d -v threadtime | grep -E "10-31 15:42:(0|1[0-4])" | \
  grep -iE "dpc|provision|ProfileOwner|DevicePolicy|Start proc|parentalcontrols"
```

## Backups

Before any edit, back up both files to a location that survives the restart (`/sdcard`, since `/data` state is what's being modified):

```sh
mkdir -p /sdcard/dpbak
cp /data/system/users/0/profile_owner.xml /data/system/device_policies.xml /sdcard/dpbak/
```

To restore the original state (package must be reinstalled first if already removed):

```sh
cmd package install-existing --user 0 com.amazon.parentalcontrols   # if needed
cp /sdcard/dpbak/device_policies.xml /data/system/device_policies.xml
cp /sdcard/dpbak/profile_owner.xml /data/system/users/0/profile_owner.xml
chown system:system /data/system/device_policies.xml /data/system/users/0/profile_owner.xml
chmod 600 /data/system/device_policies.xml /data/system/users/0/profile_owner.xml
reboot
```

A full factory reset also restores everything, since none of this touches `/system`.

## Caveats / things that are device- or build-specific

- Component and class names (`ParentalBootBroadcastReceiver`, `ParentalAdminReceiver`) were read directly from `dumpsys`/`logcat` on this specific Fire OS 8 build. Confirm against your own device's `dumpsys device_policy` output rather than assuming these match — Amazon could rename classes between Fire OS versions.
- This device had **AVB on, dm-verity off**. Nothing here touches `/system`, so this should be equally safe regardless of that combination, but it's worth stating the tested configuration.
- Requires temporary or persistent root the whole way through; none of this works from a stock `adb shell`.
