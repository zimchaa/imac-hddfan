#!/bin/bash
# Control the iMac12,2 HDD fan (fan2) manually: the SMC pins it at max
# when the HDD temp sensor is missing.
S=/sys/devices/platform/applesmc.768
LOW=2000 HIGH=5500      # rpm
T_LOW=50 T_HIGH=75      # °C: ramp between these
HYST=250                # rpm: ignore smaller changes to avoid audible hunting
SENSORS="TC0P TG0p TS0P TPCD"
# Resolve sensor labels to input files once.
inputs=()
for i in "$S"/temp*_label; do
  for k in $SENSORS; do [ "$(tr -d ' ' <"$i")" = "$k" ] && inputs+=("${i%_label}_input"); done
done
restore() { echo 0 > $S/fan2_manual; exit 0; }
trap restore TERM INT
cur=0
while :; do
  # The SMC drops back to auto (and full speed) after suspend/resume,
  # so re-assert manual mode every pass.
  if [ "$(cat $S/fan2_manual)" != 1 ]; then echo 1 > $S/fan2_manual; cur=0; fi
  t=0
  for f in "${inputs[@]}"; do v=$(( $(cat "$f") / 1000 )); [ $v -gt $t ] && t=$v; done
  if   [ $t -le $T_LOW ];  then rpm=$LOW
  elif [ $t -ge $T_HIGH ]; then rpm=$HIGH
  else rpm=$(( LOW + (HIGH-LOW)*(t-T_LOW)/(T_HIGH-T_LOW) )); fi
  d=$(( rpm - cur )); [ ${d#-} -ge $HYST ] && { echo $rpm > $S/fan2_output; cur=$rpm; }
  sleep 5 & wait $!
done
