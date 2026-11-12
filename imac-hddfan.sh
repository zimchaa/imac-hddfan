#!/bin/bash
# Control the iMac12,2 HDD fan (fan2) manually: the SMC pins it at max
# when the HDD temp sensor is missing.
S=/sys/devices/platform/applesmc.768
LOW=2000 HIGH=5500      # rpm
T_LOW=50 T_HIGH=75      # °C: ramp between these
HYST=250                # rpm: ignore smaller changes to avoid audible hunting
SENSORS="TC0P TG0p TS0P TPCD"
# Kernels from ~7.x expose the standard hwmon files under $S/hwmon/hwmonN
# (pwm2_enable: 1=manual 2=auto, fan2_target); older ones use fan2_manual
# and fan2_output directly under $S.
D=$(echo "$S"/hwmon/hwmon*)
if [ -e "$D/pwm2_enable" ]; then
  MODE=$D/pwm2_enable MANUAL=1 AUTO=2 OUT=$D/fan2_target
elif [ -e "$S/fan2_manual" ]; then
  D=$S MODE=$S/fan2_manual MANUAL=1 AUTO=0 OUT=$S/fan2_output
else
  echo "applesmc fan2 control not found" >&2; exit 1
fi
# Resolve sensor labels to input files once.
inputs=()
for i in "$D"/temp*_label; do
  for k in $SENSORS; do [ "$(tr -d ' ' <"$i")" = "$k" ] && inputs+=("${i%_label}_input"); done
done
# Without sensors the fan would sit at LOW however hot it gets: leave it to the SMC.
[ ${#inputs[@]} -gt 0 ] || { echo "no sensors found ($SENSORS)" >&2; exit 1; }
restore() { echo $AUTO > $MODE; exit 0; }
trap restore TERM INT
cur=0
while :; do
  # The SMC drops back to auto (and full speed) after suspend/resume,
  # so re-assert manual mode every pass.
  if [ "$(cat $MODE)" != $MANUAL ]; then echo $MANUAL > $MODE; cur=0; fi
  t=0
  for f in "${inputs[@]}"; do
    v=$(cat "$f" 2>/dev/null)
    # A failed read counts as hot, so the fan goes to HIGH rather than LOW.
    [[ $v =~ ^[0-9]+$ ]] && v=$(( v / 1000 )) || v=$T_HIGH
    [ $v -gt $t ] && t=$v
  done
  if   [ $t -le $T_LOW ];  then rpm=$LOW
  elif [ $t -ge $T_HIGH ]; then rpm=$HIGH
  else rpm=$(( LOW + (HIGH-LOW)*(t-T_LOW)/(T_HIGH-T_LOW) )); fi
  d=$(( rpm - cur )); [ ${d#-} -ge $HYST ] && { echo $rpm > $OUT; cur=$rpm; }
  sleep 5 & wait $!
done
