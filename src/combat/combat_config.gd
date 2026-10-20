class_name CombatConfig
## Tunables from 위지란-플레이어-전투-구현기획서.md (2026-10-14). Seconds and viewport pixels.
## Rules live in the code that reads them; only numbers belong here.

enum ParryClass { NORMAL, PERFECT_ONLY, UNPARRYABLE }

const PLAYER_MAX_HP := 100
const PLAYER_ARMOR := 0.0

# 5. Space parry timeline (start inclusive, end exclusive) and recoveries
const PARRY_PERFECT_END := 0.100
const PARRY_PARTIAL_END := 0.250
const PARRY_FAIL_END := 0.450
const PARRY_PERFECT_RECOVERY := 0.10
const PARRY_PARTIAL_RECOVERY := 0.18
const PROTECT_PERFECT := 0.06
const PROTECT_PARTIAL := 0.12
const PARTIAL_DAMAGE_RATE := 0.30
const PARTIAL_KNOCKBACK_RATE := 0.25
const PARRY_AIR_SPEED_KEEP := 0.5
const PERFECT_QI := 10.0
const PERFECT_RIFT := -10.0
const PERFECT_GAUGE := 12.0
const COUNTER_WINDOW := 1.20
const COUNTER_INJURY := 2
const COUNTER_LUNGE_RATE := 1.25
const NORMAL_ENEMY_RECOIL := 0.30
const HITSTOP_PERFECT := 0.06
const HITSTOP_PARTIAL := 0.025

# 7. common hurt rules and dash i-frames
const HURT_STUN := 0.25
const PROTECT_HURT := 0.35
const DASH_IFRAME_START := 0.020
const DASH_IFRAME_END := 0.130
const ARMOR_MAX := 0.80

# 4. air jump
const AIR_JUMP_SPEED := 340.0
const AIR_JUMP_SIDE_SPEED := 220.0

# 6. posture (boss stagger)
const POSTURE_MAX := 100.0
const POSTURE_NORMAL := 25.0
const POSTURE_HEAVY := 40.0
const POSTURE_DECAY_DELAY := 3.0
const POSTURE_DECAY_RATE := 10.0
const STAGGER_DURATION := 2.5
const STAGGER_IMMUNITY := 1.0

# 8. internal injury (내상)
const INJURY_MAX := 3
const INJURY_DURATION := 6.0
const BURST_PER_STACK := 8.0
const HEAVY_BURST_PER_STACK := 12.0

# 8-9. heavy moon (강화 만월), 내공/마열
const QI_MAX := 100.0
const QI_REGEN := 20.0
const RIFT_MAX := 100.0
const HEAVY_QI_COST := 25.0
const HEAVY_RIFT_GAIN := 30.0
const HEAVY_DAMAGE := 42.0
const HEAVY_RECOVERY_EXTRA := 0.10
const EROSION_RECOVERY_EXTRA := 0.15
const OVERHEAT_RIFT := 50.0
const OVERHEAT_BURST_RATE := 1.20
const EROSION_ENTER := 85.0
const EROSION_EXIT := 60.0
const RIFT_DECAY_DELAY := 1.5
const RIFT_DECAY_RATE := 12.0
const GAUGE_PER_ATTACK := 4.0

# 10. 월식 (ultimate)
const ULT_QI_COST := 60.0
const ULT_GAUGE_COST := 100.0
const ULT_COOLDOWN := 20.0
const ULT_PREP := 0.30
const ULT_TOTAL := 0.85
const ULT_RADIUS := 150.0
const ULT_DIRECT := 50.0
const ULT_BURST_PER_STACK := 15.0
const ULT_IFRAME_START := 0.10
const ULT_IFRAME_END := 0.45
const TREMOR_DURATION := 4.0


## 7. damage formula: armor applies fully to direct damage and at a quarter to internal damage.
## One rounding at the end; positive raw damage never rounds below 1.
static func final_damage(raw_direct: float, raw_internal: float, armor_rate: float, rate: float = 1.0) -> int:
	var armor := clampf(armor_rate, 0.0, ARMOR_MAX)
	var total := (raw_direct * (1.0 - armor) + raw_internal * (1.0 - armor * 0.25)) * rate
	if raw_direct + raw_internal <= 0.0:
		return 0
	return maxi(1, int(floor(total + 0.5)))
