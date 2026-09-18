# RS_SlowMo

The trigger for the engine's slow motion. **The world slows. You do not.**

Your head, your hands and your gun keep full speed; everything else — monsters, their shots, your
own bullets once they leave the barrel, doors, lifts — runs at a fraction. In VR that is not a
stylistic choice: a tracked head cannot be slowed without making someone ill, so the only slow
motion that works is the world getting slow around you.

## What this package is, and what it is not

The **engine** owns the clock (slow motion, engine build 13, exe 09-18 08:36): it takes a scale and
runs the world's tics less often. It deliberately ships **no console command that writes the scale**,
because a command would be one machine's and the world is everyone's. A replicated network event is
the only door, so something has to knock. This package is that something — and today it is the only
thing in the load order that calls `LevelLocals.SetTimeScale`.

It is small on purpose: a key, a ramp, and the sound of the world sagging. What each effect DOES
inside slow motion belongs to the package that owns the effect (see below).

## Using it

Add `RS_SlowMo.pk3` to the load order. Then:

- **Bind a key:** Options → Customize Controls → **Slow Motion** → "Slow motion on/off".
- **Settings:** Options → **Slow Motion**.
- **From the console**, if you would rather: `slowmo`, `slowmo_on`, `slowmo_off`, and `slowmo_state`
  which prints the scale and where it is heading.

| Setting | Whose | What |
|---|---|---|
| `rsm_depth` | server | How slow, while it is on. 0.25 (quarter speed) by default; 0 is a full freeze. |
| `rsm_ramp_in` | server | Seconds to slow down over. 0.15 by default — snapping reads as a stutter, not as time bending. |
| `rsm_ramp_out` | server | Seconds to come back over. 0.40 by default: leaving is slower than arriving. |
| `rsm_sound_follow` | user | How far world sounds drop in pitch with the world. Your own gun, the menus and anything real-time keep their pitch. |

Depth and the ramps are **server** cvars because there is one world and they change what everyone's
game does. The sound is **user** because it is a look on your own machine and never reaches the
playsim.

A map change always puts the world back at full speed.

## How it hangs together

```
a key -> the `slowmo` alias -> netevent rsm_toggle -> NetworkProcess on EVERY machine
      -> the target changes -> WorldTick eases the scale -> level.SetTimeScale
```

`NetworkProcess` is the replicated door: the event lands on every machine on the same tic, so every
machine sets the same scale from the same state and the worlds stay identical. Nothing here is
random. The only thing that reads `consoleplayer` is the sound pitch — a look on your own machine,
which is the one case the netplay rule allows.

The ramp runs on **`WorldTick`** (every real tic), never `WorldStep`. At a deep slow motion a ramp on
world time would ease in slow motion too and never arrive, and at a full freeze the world stops
stepping entirely — nothing would ever turn it back on.

## What lives elsewhere

- **RS_Ballistics** decides which of its own effects keep real time. Recoil recovery and the whole
  barrel — heat, cooling, glow, shimmer — are on the real clock, because your gun cycles at full
  speed. Its muzzle flash is a **choice**: Options → Ballistics & Effects → "Muzzle flash in slow
  motion" → *Snaps* or *Blooms and hangs*.
- **The engine** slows GPU particles, emissive volumes, effect lights, stamps, beams and the
  client-side effect thinkers, and exempts actors marked `+REALTIME`.

## Not built yet

- **The colour drain.** The owner's design has the world desaturating as it slows. That wants a
  postprocess shader, which is a different kind of work from this handler.
- **A gesture.** The plan is for a VR gesture to press the same toggle. It will send the same
  network event; nothing here changes when it does.
- **Triggering it off the fight** — a round passing close to your head dropping the world for a beat.
  RS_Ballistics already detects the near miss, so the hook is cheap; it is an idea, not a commission.
