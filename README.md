### Note
This project was REMOVED from XDA Forums because it was assisted (and mostly generated) with AI (it HAS been tested on a real FireOS device). I understand that. It just means this project may not go far. The mod, Oswald Boelcke, said: "Thread closed and link removed! Only OWN development qualifies for a development section, and we don't recognise "Claude" as one of our members!" I feel like that could have been worded nicer and better, even if I forgot to read the rules.
# FireOS 8: Parental Controls Off
This exploit was tested with the Fire 7 12th generation temp root exploit, shown at the bottom of this README.md.
Removes Parental Controls from FireOS 8 (tested on 8.3.3.8). Requires temp root. Gets more apps working and deletes Work Profile!
## Warning
I am not responsible for any damage done to your device. Please use this responsible, and do not use this for malicious content.
No permanent modifications are made (can survive a reboot), and can be reset. dm-verity is not triggered.
This may not work on your device, but it should work if you use a similar FireOS version. I cannot ensure that this works with every FireOS device, let alone every 12th and 13th gen device, but attempting this should not harm your device. You should still backup any important data just in case, as stuff that needs root has the potential to break something.
## READ THIS.
Pleae do NOT use this to bypass Parental Controls restrictions if Parental Controls is turned on. That is not the intended purpose--this is meant to get more apps working, as Parental Controls being the profile/device admin causes Work Profile, which makes some apps not work. If you are the parent of your kid, and you discover this repository, please make sure your child does not have access to Developer Options or USB Debugging.
## What apps will work by using this?
This mostly includes AI apps. More apps will be added when found.
- Gemini
- ChatGPT
- Apps that need Profile/Device Owner to run stuff, such as Dhizuku
## Why does this need temp root?
According to the AI, this requires temporary root because it needs to access /data directories not accessible in ADB. That makes sense.
## Was this made by AI?
Yes, particularly using Claude.
## How do I run this?
- Make sure ADB is installed on your device. If not, install it to your device.
- Run a temporary root exploit. (links at the bottom of the README)
- Clone this repository, or use Download ZIP and extract.
- Open a terminal in the directory of the repository.
- Run the remove.sh (remove.bat if using Windows) script.
- Now it should be running! Enjoy.
## How do I get temporary root, anyway?
These contain links to temporary root exploits for different FireOS 8 devices. I have not checked the safety of most of these, proceed with caution. Know that your software version may not be supported:
### Fire 7 (12th generation) (KNOWN WORKING IN MY TESTING)
https://xdaforums.com/t/root-amazon-fire-7-2022-12th-gen.4807113/
A bootloader unlock is possible for this device, however the way currently is not public as of 10/31/2026.
### Fire HD 8 (12th generation)
https://xdaforums.com/t/root-amazon-fire-hd-8-2022-12th-gen.4801332/#post-90772905
### Fire HD 10 (13th generation)
https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/page-5#post-90742465
### Fire Max 11 (13th generation)
https://xdaforums.com/t/temp-root-fire-max-11-2023-sunstone.4798590/
A bootloader unlock is possible for this device, and the way is public.
## Hey, can I use this in my project?
For sure. Use this in any project you want, just give me credit!
