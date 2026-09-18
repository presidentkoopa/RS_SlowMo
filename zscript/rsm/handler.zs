// ============================================================================
// RS_SlowMo -- the trigger, the ramp and the sound of the world slowing down.
//
// THE ENGINE OWNS THE CLOCK (slow motion, engine build 13). It takes a scale and
// runs the world's tics less often; your head, your hands and anything marked
// +REALTIME keep full speed. This mod is the only thing that asks it to, because
// the engine deliberately ships NO console command that writes the scale -- a
// command would be one machine's, and the world is everyone's.
//
// THE PATH, and why it is this shape:
//   a key -> the `slowmo` alias -> `netevent rsm_toggle` -> NetworkProcess on EVERY
//   machine -> m_target changes -> WorldTick eases m_scale toward it and calls
//   level.SetTimeScale.
// NetworkProcess is the replicated door: the event arrives on every machine on the
// same tic, so every machine sets the same scale from the same state and the worlds
// stay identical. Nothing here is random, and the only thing that reads consoleplayer is the sound
// pitch -- a look on your own machine, which is the one case the netplay rule allows it.
//
// WHAT IS A CHOICE AND WHAT IS A RULE (netplay):
//   DEPTH and the RAMPS are the world's -- they change what everyone's game does,
//   so they are `server` cvars, which is GZDoom's word for "the host decides".
//   THE SOUND PITCH is a look. It is local, it is `user`, and it never reaches the
//   playsim: Object.S_SetWorldPitch is presentation only.
//
// WORLD TICK, NOT WORLD STEP. The ramp has to run on the REAL clock, or at a deep
// slow motion it would ease in slow motion too and never arrive -- and at a full
// freeze the world stops stepping entirely and nothing would ever turn it back on.
// WorldTick is every real tic, which is what this wants.
// ============================================================================

class RSM_Handler : StaticEventHandler
{
	// The eased scale, and where it is heading. 1.0 is the world at full speed.
	private double m_scale;
	private double m_target;
	private bool   m_on;
	private double m_pitch;    // the world pitch last asked for, so we only ask on a change

	override void OnRegister()
	{
		m_scale = 1.0;
		m_target = 1.0;
		m_on = false;
		m_pitch = 1.0;
	}

	// THE DOOR. Every machine runs this on the same tic with the same argument.
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "rsm_toggle")       Aim(!m_on);
		else if (e.Name ~== "rsm_on")      Aim(true);
		else if (e.Name ~== "rsm_off")     Aim(false);
		else if (e.Name ~== "rsm_state")
			Console.Printf("slow motion: %s, scale %.2f heading for %.2f (depth %.2f)",
				m_on ? "ON" : "off", m_scale, m_target, Depth());
	}

	private void Aim(bool on)
	{
		m_on = on;
		m_target = on ? Depth() : 1.0;
	}

	// A CVAR'S VALUE, OR THE FALLBACK -- never a crash. A `user` cvar has no value until it is asked
	// for on behalf of a player, so CVar.GetCVar("rsm_sound_follow") with no player returns NULL in a
	// static handler, and GetFloat on null is a VM abort that kills the map. That is exactly how this
	// was caught (boot test, 2026-09-18) and it is why every read here goes through one guarded door.
	private static double Cvf(String name, double fallback, bool mine = false)
	{
		CVar c = null;
		if (mine)
		{
			// A LOCAL LOOK, so this machine's own player is the right one to ask. The netplay rule bars
			// consoleplayer from anything the GAME reads; a sound pitch is not that.
			if (playeringame[consoleplayer]) c = CVar.GetCVar(name, players[consoleplayer]);
		}
		else c = CVar.GetCVar(name);
		return c ? c.GetFloat() : fallback;
	}

	// THE WORLD'S SETTINGS, the host's: read fresh every tic so a slider moves while it runs.
	private double Depth()   { return clamp(Cvf("rsm_depth", 0.25), 0.0, 0.95); }
	private double RampIn()  { return max(0.0, Cvf("rsm_ramp_in", 0.15)); }
	private double RampOut() { return max(0.0, Cvf("rsm_ramp_out", 0.40)); }

	override void WorldTick()
	{
		if (!level) return;

		// EASE, NEVER SNAP. Slamming to a fifth speed in one tic reads as a stutter, not as time
		// bending. Each ramp is a time in seconds to cross the whole distance, so a shallow slow
		// motion arrives sooner than a deep one -- which is what it should feel like.
		if (m_on) m_target = Depth();   // the slider moved while it was running
		double want = m_target;
		if (m_scale != want)
		{
			double secs = (want < m_scale) ? RampIn() : RampOut();
			if (secs <= 0.001)
			{
				m_scale = want;
			}
			else
			{
				double step = (1.0 / (secs * TICRATE));
				if (abs(want - m_scale) <= step) m_scale = want;
				else m_scale += (want > m_scale) ? step : -step;
			}
		}
		level.SetTimeScale(m_scale);

		// THE SOUND OF IT, presentation only and this machine's alone. World sounds drop in pitch
		// with the world; your own gun, the UI and anything real-time are exempt in the engine, so
		// the shot stays sharp while the room sags around it. Asked for only when it changes.
		double follow = clamp(Cvf("rsm_sound_follow", 1.0, true), 0.0, 1.0);
		double pitch = 1.0 - (1.0 - m_scale) * follow;
		pitch = clamp(pitch, 0.25, 1.0);
		if (abs(pitch - m_pitch) > 0.002)
		{
			Object.S_SetWorldPitch(pitch);
			m_pitch = pitch;
		}
	}

	// A MAP CHANGE puts the world back at full speed: a level should never start slowed.
	override void WorldLoaded(WorldEvent e)
	{
		m_on = false;
		m_target = 1.0;
		m_scale = 1.0;
		if (level) level.SetTimeScale(1.0);
		Object.S_SetWorldPitch(1.0);
		m_pitch = 1.0;
	}
}
