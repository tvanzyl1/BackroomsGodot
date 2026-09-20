# Backrooms: Yellow Maze

A small desktop-first first-person maze prototype for Godot 4.7.2 stable.

## Run

1. Open `project.godot` in Godot 4.7.2.
2. Press Play. A new maze is generated on every run.
3. Use `WASD` to move and the mouse to look.
4. Press `R` to start a new game. Find the orange light at the far end to advance to the next level.
5. Press `Escape` to release the mouse cursor.

The maze, collision, lighting, player, and HUD are created procedurally at runtime. No external assets are required.

To-do list:
1. [x] Player health bar
2. [x] On collision with the howler the player should lose 10% health.
3. [x] Some rare health orbs to be picked up by the player
4. [x] On collision with howler and on pickup of the health there should be visual indicators. ie. red slash on attack or healing particles on pickup.
5. [x] The Howler should have better noise detection to follow/stalk the player better.
5.1 [x] Something like following noise when hearing it for a certain radius
5.2 [x] follow player's last detected position, to make sure he doesn't just lose the player around a corner.
5.3 [x] Wider view detection.
6. [x] A win state; when getting to the ending a message showing that you've exited the backrooms.
7. [x] A death state. When your health is 0, the camera falls to the ground and red covers the screen. Message pops up that you are dead and asks if you want to start again.
8. [x] Howler should now start in a random spot in the map.
9. [x] Howler should take 40% of player health on collision. 
10. [x] Health orbs should only be picked up if the player health is less than 100. 
11. [x] Start state with a message "You've landed in a strange backrooms, press any key to start".
12. [x] Add some "oversized" rooms so the maze is not just coridors.
13. [x] Implement flashlight battery life. We need
13.1. [x] A battery life bar under the health bar.
13.2. [x] Every second the flashlight is on, the battery reduces with 1%. When off, no reduction.
13.3. [x] Three battery game states, 1. Battery never depletes, 2. Battery depletes when on, but recharges 1% per second it is off, 3. Battery depletes when on, but does not recharge.
13.4. [x] The battery game states can be selected at the start of the game. This will help indicate difficulty.
14. [x] Player attack
14.1. [x] Left click when close to the Howler hits it.
14.2. [x] The Howler should start wiht 100 health on game starts
14.3. [x] The player attack should do 10 damage to the Howler.
14.4. [x] The Howler should die on 0 health.
14.5. [x] After 10 seconds of Howler death a new instance should be spawned in the maze.
14.6. [x] When the player can see the Howler then the Howler's health bar should be visible. And purple. 
15. [x] When the Howler dies, it should disappear instantly and respawn 10 seconds later.
16. [x] Add levelling.
16.1. [x] When the player presses R for a new game the user should be prompted if they are sure as this will take them back to level 1
16.2. [x] The game starts on level 1
16.3. [x] When the player finds the exit, the level is increased.
16.4. [x] On level increase, the map becomes bigger. i.e. bigger maze.
16.5. [x] On level increase, the Howler gets 10% more health.
17. [x] Howler increasing aggressiveness
17.1 [x] As the player progresses through levels, the Howler becomes more aggressive, with less stalking and more chasing.
17.2 [x] The player can run using the `shift` key, which increases speed and movement noise.
18. [x] Player Walking and running sounds
18.1. [x] Implement walking sounds using Audio/PlayerWalking.mp3
18.2. [x] Implement running sound using Audio/PlayerRunning.mp3