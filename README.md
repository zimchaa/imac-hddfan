# imac-hddfan

Fan control for a 2011 iMac (iMac12,2) running Linux after its hard drive has been replaced with an SSD or a non-Apple drive.

## The problem

Apple's original hard drives have a built-in temperature sensor wired to the SMC (the chip that controls the fans). Swap in a different drive and the SMC can't read the drive temperature, so it runs the HDD fan at or near full speed (~5500 RPM).

## What this does

A small systemd service takes the HDD fan (`fan2`) into manual mode through the `applesmc` kernel driver. It then sets the speed from the hottest of the CPU, GPU and other board sensors:

| Hottest sensor | Fan speed |
|---|---|
| 50°C or below | 2000 RPM |
| 50–75°C | linear ramp |
| 75°C or above | 5500 RPM |

- Manual mode is re-applied every 5 seconds, because the SMC switches back to automatic after suspend/resume.
- Changes under 250 RPM are ignored, so the fan doesn't keep hunting.
- When the service stops, the fan goes back to SMC control.

Tune `LOW`, `HIGH`, `T_LOW`, `T_HIGH`, `HYST` and `SENSORS` at the top of `imac-hddfan.sh`.

## Install

```
sudo ./install.sh
```

## Check it

```
S=/sys/devices/platform/applesmc.768
cat $S/fan2_manual $S/fan2_output $S/fan2_input   # expect 1, target, actual RPM
```

To list sensor names on your machine: `grep . $S/temp*_label`.

## Other models

Other 2009–2011 iMacs have the same problem, but their fan numbers, speed limits and sensor names can differ. Check `$S/fan*_label` and `$S/temp*_label` before using this on another model.
