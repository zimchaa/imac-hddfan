#!/bin/bash
# Record fan speeds and temperatures through idle, full CPU load and cooldown.
# No root needed. Usage: test/fan-test.sh [out.csv] [idle_s] [load_s] [cool_s]
OUT=${1:-fan-test.csv} IDLE=${2:-180} LOAD=${3:-900} COOL=${4:-300}
STEP=2
S=/sys/devices/platform/applesmc.768
D=$(echo "$S"/hwmon/hwmon*); [ -e "$D/fan2_input" ] || D=$S
SENSORS="TC0P TG0p TS0P TPCD TH0O"
declare -A in
for i in "$D"/temp*_label; do
  k=$(tr -d ' ' <"$i"); [[ " $SENSORS " == *" $k "* ]] && in[$k]=${i%_label}_input
done
pkg=$(grep -l '^Package' /sys/class/hwmon/hwmon*/temp*_label | head -1); pkg=${pkg%_label}_input
mode=$D/pwm2_enable; [ -e "$mode" ] || mode=$S/fan2_manual
target=$D/fan2_target; [ -e "$target" ] || target=$S/fan2_output

pids=()
stop_load() { [ ${#pids[@]} -gt 0 ] && kill "${pids[@]}" 2>/dev/null; pids=(); }
trap 'stop_load; exit 1' INT TERM

# Average busy % across all cores since the previous call, from /proc/stat.
prev_total=0 prev_idle=0
cpu_load() {
  local _ user nice sys idle iow irq soft steal total
  read -r _ user nice sys idle iow irq soft steal _ </proc/stat
  total=$(( user + nice + sys + idle + iow + irq + soft + steal )); idle=$(( idle + iow ))
  load=$(( total > prev_total ? 100 * (total - prev_total - idle + prev_idle) / (total - prev_total) : 0 ))
  prev_total=$total prev_idle=$idle
}
cpu_load

echo "t,phase,manual,fan2_target,fan2_rpm,fan1_rpm,fan3_rpm,cpu_load,cpu_pkg,$(echo $SENSORS | tr ' ' ,)" >"$OUT"
start=$(date +%s)
for phase in idle load cool; do
  case $phase in idle) dur=$IDLE ;; load) dur=$LOAD ;; cool) dur=$COOL ;; esac
  if [ $phase = load ]; then for _ in $(seq "$(nproc)"); do yes >/dev/null & pids+=($!); done; fi
  [ $phase = cool ] && stop_load
  end=$(( $(date +%s) + dur ))
  while [ "$(date +%s)" -lt $end ]; do
    cpu_load
    row="$(( $(date +%s) - start )),$phase,$(cat $mode),$(cat $target)"
    row+=",$(cat $D/fan2_input),$(cat $D/fan1_input),$(cat $D/fan3_input),$load,$(( $(cat $pkg) / 1000 ))"
    for k in $SENSORS; do row+=",$(( $(cat ${in[$k]}) / 1000 ))"; done
    echo "$row" >>"$OUT"; echo "$row"
    sleep $STEP
  done
done
