I am building a 3D horror game in Godot 4.x.

I want you to implement a hostile creature inspired by the Backrooms entity known as the **Howler**.

The creature should be frightening because of its behaviour, sound design and unpredictability rather than simply having lots of health.

## Goal

Create a reusable Godot enemy called `Howler` that can patrol, investigate sounds, detect the player, stalk them, chase them and attack them.

The implementation should be modular enough that I can reuse or modify it for other creatures later.

Do not build the entire game. Implement the Howler as a self-contained enemy system that can be dropped into an existing level.

---

# 1. Scene Structure

Create a scene:

`Howler.tscn`

Suggested hierarchy:

Howler (CharacterBody3D)
├── CollisionShape3D
├── ModelRoot (Node3D)
│   └── creature model / placeholder mesh
├── NavigationAgent3D
├── VisionOrigin (Marker3D)
├── AttackOrigin (Marker3D)
├── Audio
│   ├── IdleAudio (AudioStreamPlayer3D)
│   ├── HowlAudio (AudioStreamPlayer3D)
│   ├── ChaseAudio (AudioStreamPlayer3D)
│   └── AttackAudio (AudioStreamPlayer3D)
├── AnimationPlayer or AnimationTree
├── StateMachine
└── DebugVisuals

Use placeholder geometry if no creature model is available.

Do not make the implementation dependent on a specific model.

---

# 2. Core Behaviour

Use a finite state machine.

States:

IDLE
PATROL
INVESTIGATE
STALK
ALERT
CHASE
SEARCH
ATTACK
STUNNED
DEAD

The state machine should be easy to extend.

Avoid putting all behaviour in one enormous `_physics_process()` function.

---

# 3. Idle Behaviour

When idle, the Howler should:

* occasionally stand completely still
* make subtle breathing/growling sounds
* slowly turn its head or body
* occasionally emit a distant howl
* sometimes transition into patrol mode

Idle behaviour should use randomised timers so it does not feel scripted.

Example idle duration:

3–10 seconds.

Expose these values as editable exported variables.

---

# 4. Patrol Behaviour

The Howler should wander using Godot's NavigationServer / NavigationAgent3D system.

It should choose random valid navigation positions within a patrol radius.

Example:

`patrol_radius = 20 metres`

Movement should be relatively slow during patrol.

Example:

`patrol_speed = 2.0`

The creature should occasionally stop and listen.

---

# 5. Player Detection

The Howler should detect the player using multiple senses.

## Vision

Give the creature:

* configurable detection range
* configurable field of view
* raycast line-of-sight checking

Example:

vision_range = 18 metres
vision_angle = 90 degrees

Walls must block vision.

Do not detect the player simply because they are within a radius.

## Hearing

The Howler should also react to noise.

Create a reusable noise-event system such as:

`NoiseManager.emit_noise(position, loudness, source)`

Examples:

walking = low noise
running = medium noise
jumping = medium noise
objects falling = high noise
gunshots = extremely high noise

The Howler should investigate sufficiently loud noises.

Detection distance should depend on loudness.

---

# 6. Investigation Behaviour

When the Howler hears something but cannot see the player:

1. remember the sound position
2. move towards it
3. slow down as it approaches
4. search the surrounding area
5. look around
6. occasionally growl or make a quiet howl

If the player is discovered, enter CHASE.

If nothing is found after a configurable period, return to patrol.

---

# 7. Stalking Behaviour

Sometimes the Howler should detect the player without immediately attacking.

Instead it enters STALK mode.

During stalking:

* keep some distance from the player
* move between nearby navigation positions
* try not to remain directly in the player's field of view
* occasionally appear briefly at the end of corridors
* stop moving when the player looks directly at it
* disappear around corners when possible
* emit quiet sounds from nearby positions

Stalking should last roughly 5–20 seconds.

Then it may:

* retreat
* continue stalking
* howl
* begin chasing

Use weighted random choices.

The goal is to create uncertainty rather than predictable behaviour.

---

# 8. Alert / Howl

When the creature commits to an attack:

1. stop moving briefly
2. face the player
3. play the Howler's howl sound
4. play a howl animation if available
5. delay approximately 0.5–1.5 seconds
6. enter CHASE state

The howl should act as an audio warning to the player.

Do not allow the warning animation to freeze the entire game.

---

# 9. Chase Behaviour

During CHASE:

* increase movement speed substantially
* continuously update navigation towards the player
* use acceleration instead of instantly changing velocity
* turn naturally rather than snapping direction
* play chase animation
* play aggressive breathing / vocalisations

Example values:

patrol_speed = 2 m/s
investigate_speed = 3 m/s
chase_speed = 7 m/s

The creature should periodically update its path rather than recalculating navigation every frame unnecessarily.

---

# 10. Losing the Player

If line of sight is lost:

remember:

`last_known_player_position`

Continue chasing toward that point.

If the player is not rediscovered:

enter SEARCH.

Search nearby locations for approximately 5–15 seconds.

If unsuccessful:

return to patrol.

Detection should gradually decrease rather than instantly forgetting the player.

---

# 11. Attack Behaviour

If the player enters attack range:

`attack_range = approximately 1.5–2 metres`

enter ATTACK.

The attack should:

* face the player
* play an attack animation
* apply damage during a specific attack window
* have an attack cooldown
* prevent repeated damage every frame

Example:

attack_damage = 30
attack_cooldown = 1.5 seconds

Use either an Area3D hitbox or animation event to determine when damage occurs.

Do not damage the player merely because they are near the enemy.

---

# 12. Horror Behaviour

Add subtle unpredictable behaviour.

Examples:

The Howler occasionally:

* stops chasing for a moment
* walks rather than runs
* watches the player from a distance
* emits a howl from another corridor
* retreats after being spotted
* becomes completely silent
* suddenly resumes pursuit

These behaviours should have relatively low probability.

The player should never be entirely certain what the creature is going to do.

---

# 13. Sound Design Hooks

Create clearly named variables where I can later assign audio resources.

Examples:

idle_breathing_sound
distant_howl_sound
alert_howl_sound
chase_growl_sound
attack_sound
footstep_sounds

Use AudioStreamPlayer3D so sound attenuates through distance.

The creature's location should sometimes be detectable through audio before it is visible.

---

# 14. Animation Hooks

Create support for:

idle
walk
run
stalk
howl
attack
stunned
death

If animations do not exist, the code must continue to work without producing errors.

Use either AnimationPlayer or AnimationTree.

Do not tightly couple behavioural logic to exact animation names without configurable parameters.

---

# 15. Configuration

Expose important parameters in the Godot inspector using `@export`.

Include categories such as:

Movement

patrol_speed
investigate_speed
chase_speed
acceleration
turn_speed

Detection

vision_range
vision_angle
hearing_multiplier
detection_time

Combat

attack_range
attack_damage
attack_cooldown

Behaviour

patrol_radius
idle_time_min
idle_time_max
search_duration
stalk_probability
stalk_duration_min
stalk_duration_max
random_behaviour_probability

---

# 16. Player Interface

Do not assume the exact implementation of my player.

Use loose interfaces where possible.

For example:

if player.has_method("take_damage"):
player.take_damage(attack_damage)

Find the player using a configurable group:

`player`

Avoid hard-coded scene paths such as:

`../../../Player`

---

# 17. Debugging Tools

Add an optional:

`@export var debug_mode: bool`

When enabled, show useful information such as:

current state
detected player
last known player position
current navigation target
vision status
heard noise position

Use Godot debug drawing or labels where practical.

Debug features must be disabled by default.

---

# 18. Performance

Do not perform expensive physics queries unnecessarily every frame.

Detection and path updates can run at intervals.

For example:

vision checks every 0.1 seconds
navigation target update every 0.2 seconds

The architecture should support multiple Howlers existing simultaneously.

---

# 19. Code Architecture

Prefer multiple small scripts instead of one giant script.

Suggested files:

howler.gd
howler_state_machine.gd

states/
howler_idle.gd
howler_patrol.gd
howler_investigate.gd
howler_stalk.gd
howler_alert.gd
howler_chase.gd
howler_search.gd
howler_attack.gd

Optional reusable systems:

noise_manager.gd
enemy_senses.gd

Use typed GDScript where appropriate.

---

# 20. Deliverables

Implement this directly in the Godot project.

After implementation, provide:

1. a list of files created
2. a short explanation of the scene hierarchy
3. explanation of the state machine
4. instructions for adding the Howler to a level
5. required NavigationRegion3D setup
6. required player group/settings
7. instructions for connecting player-generated noise
8. inspector values that are useful for balancing the creature
9. anything still using placeholder assets

Do not create unnecessary systems unrelated to the Howler.

Prioritise getting a functional prototype working first, then improve its behaviour.
