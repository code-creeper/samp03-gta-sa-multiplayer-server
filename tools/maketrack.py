#!/usr/bin/env python3
"""
Build race tracks for filterscripts/races.pwn.

Checkpoint coordinates are never typed by hand.  Every one is snapped to a position taken
from scriptfiles/vehicles/*.txt - the 1773 parked cars grandlarc spawns at boot.  Those are
hand-placed by the SA-MP team, so each is a real on-road spot with a correct ground-level Z.

A track is described as a ring: a centre, a target radius and a checkpoint count.  The
builder walks the circle in equal angular steps and, for each step, picks the real road
position closest to the ideal point for that step.  The result is a circuit that follows
actual streets instead of whatever a straight line between two guessed coordinates would hit.

Usage:  python3 tools/maketrack.py          # regenerates every file in scriptfiles/races/
"""

import glob
import math
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "scriptfiles", "races")

# Gap limits between consecutive checkpoints, in metres.  Under MIN they stack on top of each
# other; over MAX you get a long featureless straight with no guidance.
MIN_GAP = 60.0
MAX_GAP = 900.0

# The vehicle files also contain boats, aircraft and trains.  A boat's position is out in the
# water and a Skimmer's is on a river, so snapping a checkpoint to one puts it somewhere no
# car can reach.  Only land vehicles are kept as candidate positions.
BOATS = {430, 446, 452, 453, 454, 472, 473, 484, 493, 595}
AIRCRAFT = {417, 425, 447, 460, 469, 476, 487, 488, 497, 511, 512, 513, 519, 520,
            548, 553, 563, 577, 592, 593}
TRAINS = {449, 537, 538, 569, 570, 590}
TRAILERS = {435, 450, 591, 606, 607, 608, 610, 611}
NOT_ON_ROADS = BOATS | AIRCRAFT | TRAINS | TRAILERS


def load_pool(*files):
    """Read parked-car positions out of the grandlarc vehicle files."""
    pts = []
    for name in files:
        path = os.path.join(REPO, "scriptfiles", "vehicles", name)
        for line in open(path, encoding="latin-1"):
            line = line.strip().rstrip(";").strip()
            if not line:
                continue
            parts = line.split(",")
            if len(parts) < 5:
                continue
            try:
                model = int(parts[0])
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
            except ValueError:
                continue
            if model in NOT_ON_ROADS:
                continue
            pts.append((x, y, z))
    return pts


def ring(pool, cx, cy, radius, count, start_deg=0.0, clockwise=False):
    """Pick `count` road positions forming a loop of roughly `radius` around (cx, cy)."""
    chosen = []
    used = set()
    for i in range(count):
        frac = i / count
        deg = start_deg + (-360.0 * frac if clockwise else 360.0 * frac)
        rad = math.radians(deg)
        ideal = (cx + radius * math.cos(rad), cy + radius * math.sin(rad))
        best, best_cost = None, None
        for p in pool:
            if p in used:
                continue
            # Keep a real gap from the checkpoint just placed, or the ring doubles back on
            # itself where the road bends away from the ideal circle.
            if chosen and math.dist((p[0], p[1]), chosen[-1][:2]) < MIN_GAP:
                continue
            cost = math.dist((p[0], p[1]), ideal)
            if best_cost is None or cost < best_cost:
                best, best_cost = p, cost
        if best is not None:
            used.add(best)
            chosen.append(best)
    return chosen


def facing(frm, to):
    """SA-MP z-angle facing `to` from `frm`.  0 deg is +Y (north), increasing anticlockwise."""
    dx, dy = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, dy)) % 360.0


def build(spec):
    pool = load_pool(*spec["pool"])
    cps = ring(pool, spec["cx"], spec["cy"], spec["radius"], spec["count"],
               spec.get("start_deg", 0.0), spec.get("clockwise", False))

    # Start line sits behind the first checkpoint, on the approach from the last one, snapped
    # to a real road position so nobody spawns in a wall.
    back = cps[-1]
    dx, dy = cps[0][0] - back[0], cps[0][1] - back[1]
    n = math.hypot(dx, dy) or 1.0
    ideal = (cps[0][0] - dx / n * 35.0, cps[0][1] - dy / n * 35.0)
    # Excluding the checkpoints themselves matters: the nearest road position to "just behind
    # checkpoint 1" is otherwise checkpoint 1, which spawns the grid on top of it and leaves
    # the heading undefined.
    taken = set(cps)
    candidates = [p for p in pool if p not in taken]
    start = min(candidates, key=lambda p: math.dist((p[0], p[1]), ideal))
    heading = facing(start, cps[0])

    gaps = [math.dist(cps[i][:2], cps[i + 1][:2]) for i in range(len(cps) - 1)]
    gaps.append(math.dist(cps[-1][:2], cps[0][:2]))
    return cps, start, heading, gaps


TRACKS = {
    # LS south - Idlewood, Willowfield, the lowrider turf.
    "01_lowrider.txt": dict(
        name="Lowrider Race", vehicle=536, laps=1, size=16.0,
        pool=["ls_gen_outer.txt", "ls_gen_inner.txt"],
        cx=2150, cy=-1750, radius=620, count=12),
    # LS downtown, tight and short.
    "02_littleloop.txt": dict(
        name="Little Loop", vehicle=429, laps=2, size=15.0,
        pool=["ls_gen_outer.txt", "ls_gen_inner.txt"],
        cx=1400, cy=-1400, radius=430, count=9, clockwise=True),
    # LS, the big one round the whole city.
    "03_citycircuit.txt": dict(
        name="City Circuit", vehicle=541, laps=2, size=18.0,
        pool=["ls_gen_outer.txt", "ls_gen_inner.txt"],
        cx=1500, cy=-1650, radius=1000, count=16),
    # Red County dirt and back roads.
    "04_badlands.txt": dict(
        name="Badlands", vehicle=495, laps=1, size=20.0,
        pool=["red_county.txt", "flint.txt"],
        cx=600, cy=-200, radius=900, count=12),
    # San Fierro streets and hills.
    "05_sffastlane.txt": dict(
        name="SF Fastlane", vehicle=451, laps=1, size=16.0,
        pool=["sf_gen.txt", "sf_law.txt"],
        cx=-1900, cy=500, radius=800, count=14, clockwise=True),
    # The Las Venturas outer ring.
    "06_lvringroad.txt": dict(
        name="LV Ringroad", vehicle=411, laps=2, size=18.0,
        pool=["lv_gen.txt"],
        cx=2050, cy=1650, radius=950, count=14),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    problems = 0
    for filename, spec in TRACKS.items():
        cps, start, heading, gaps = build(spec)
        with open(os.path.join(OUT, filename), "w") as fh:
            fh.write("; %s - generated by tools/maketrack.py, safe to hand-edit.\n" % spec["name"])
            fh.write("; Every cp is a real on-road position from scriptfiles/vehicles/.\n")
            fh.write("name %s\n" % spec["name"])
            fh.write("vehicle %d\n" % spec["vehicle"])
            fh.write("laps %d\n" % spec["laps"])
            fh.write("start %.4f,%.4f,%.4f,%.4f\n" % (start[0], start[1], start[2], heading))
            for c in cps:
                fh.write("cp %.4f,%.4f,%.4f,%.1f\n" % (c[0], c[1], c[2], spec["size"]))
        drowned = [c for c in cps if c[2] < 1.0]
        on_top = math.dist(start[:2], cps[0][:2]) < 5.0
        bad = [g for g in gaps if g < MIN_GAP or g > MAX_GAP]
        lap_len = sum(gaps)
        flag = ""
        if bad:
            problems += 1
            flag += "  <-- %d gap(s) outside %.0f-%.0fm: %s" % (
                len(bad), MIN_GAP, MAX_GAP, ", ".join("%.0f" % g for g in bad))
        if drowned:
            problems += 1
            flag += "  <-- %d cp(s) below z=1, check for water" % len(drowned)
        if on_top:
            problems += 1
            flag += "  <-- start line is on top of checkpoint 1"
        print("%-20s %2d cps  lap %5.0fm  gaps %3.0f-%3.0fm%s"
              % (spec["name"], len(cps), lap_len, min(gaps), max(gaps), flag))
    # races.pwn cannot list a directory, so it reads this index instead.
    with open(os.path.join(OUT, "tracks.txt"), "w") as fh:
        fh.write("; Tracks loaded by filterscripts/races.pwn, in /race order.\n")
        for filename in TRACKS:
            fh.write("%s\n" % filename)

    print("\n%d track(s) with gap problems" % problems)


if __name__ == "__main__":
    main()
