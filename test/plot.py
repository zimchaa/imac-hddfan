"""Plot a fan-test.sh CSV. Usage: python3 test/plot.py fan-test.csv fan-test.png"""
import csv
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

src, dst = sys.argv[1], sys.argv[2]
rows = list(csv.DictReader(open(src)))
t = [int(r["t"]) / 60 for r in rows]
col = lambda k: [int(r[k]) for r in rows]

fig, (ax, axl) = plt.subplots(2, 1, figsize=(11, 7.5), sharex=True, constrained_layout=True,
                              gridspec_kw={"height_ratios": [4, 1]})
axf = ax.twinx()

# Phase bands.
spans, start = [], 0
for i in range(1, len(rows) + 1):
    if i == len(rows) or rows[i]["phase"] != rows[start]["phase"]:
        spans.append((rows[start]["phase"], t[start], t[i - 1]))
        start = i
names = {"idle": "Idle", "load": "Full CPU load (all cores)", "cool": "Cooldown"}
shade = {"idle": "#ffffff", "load": "#fde8e4", "cool": "#e8f0fb"}
for a in (ax, axl):
    for phase, x0, x1 in spans:
        a.axvspan(x0, x1, color=shade[phase], zorder=0)
for phase, x0, x1 in spans:
    ax.text((x0 + x1) / 2, 1.01, names[phase], transform=ax.get_xaxis_transform(),
            ha="center", va="bottom", fontsize=9, color="#555")

# Temperatures, left axis.
lines = []
lines += ax.plot(t, col("cpu_pkg"), label="CPU package (coretemp, not a fan input)", color="#c0392b")
lines += ax.plot(t, col("TC0P"), label="CPU proximity TC0P", color="#e67e22")
lines += ax.plot(t, col("TG0p"), label="GPU proximity TG0p", color="#8e44ad")
lines += ax.plot(t, col("TPCD"), label="Platform controller TPCD", color="#16a085")
lines += ax.plot(t, col("TS0P"), label="TS0P (location undocumented)", color="#d4ac0d")
lines += ax.plot(t, col("TH0O"), label="HDD sensor TH0O (bogus with SSD)", color="#7f8c8d", ls=":")
ax.axhline(86, color="#c0392b", ls="--", lw=1)
ax.text(t[0], 86.5, "CPU critical 86°C", fontsize=8, color="#c0392b", va="bottom")
ax.axhspan(50, 75, color="#f1c40f", alpha=0.10, zorder=0)
ax.text(t[0], 74, "HDD fan ramp: hottest of TC0P/TG0p/TS0P/TPCD 50–75°C",
        fontsize=8, color="#9a7d0a", ha="left", va="top")
ax.set_ylabel("Temperature (°C)")
ax.set_ylim(0, 100)
ax.grid(alpha=0.3)

# Fan speeds, right axis.
lines += axf.plot(t, col("fan2_rpm"), label="HDD fan (fan2) actual", color="#2c3e50", lw=2.5)
lines += axf.step(t, col("fan2_target"), where="post", label="HDD fan target (imac-hddfan)",
                  color="#3498db", ls="--")
lines += axf.plot(t, col("fan3_rpm"), label="CPU fan (fan3, SMC auto)", color="#c0392b", lw=1.5, ls="-.")
lines += axf.plot(t, col("fan1_rpm"), label="ODD fan (fan1, SMC auto)", color="#27ae60", lw=1.5, ls="-.")
axf.axhline(5500, color="#2c3e50", ls=":", lw=1)
axf.text(t[-1], 5450, "HDD fan max 5500 RPM", fontsize=8, color="#2c3e50", ha="right", va="top")
axf.set_ylabel("Fan speed (RPM)")
axf.set_ylim(0, 6000)
ax.legend(lines, [l.get_label() for l in lines], loc="upper center", bbox_to_anchor=(0.5, -0.02),
          ncol=3, fontsize=8, framealpha=0.95).set_zorder(5)

# Average CPU load.
axl.fill_between(t, col("cpu_load"), color="#c0392b", alpha=0.35, step="pre", lw=0)  # each sample covers the interval before it
axl.set_ylabel("CPU load (%)")
axl.set_ylim(0, 105)
axl.set_yticks([0, 50, 100])
axl.set_xlabel("Time (minutes)")
axl.grid(alpha=0.3)

fig.suptitle("imac-hddfan on iMac12,2: temperatures, fan speeds and CPU load, idle → load → idle")
fig.savefig(dst, dpi=120)
