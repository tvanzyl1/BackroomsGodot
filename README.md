# Backrooms: Yellow Maze

A small desktop-first first-person maze prototype for Godot 4.7.2 stable.

## Run

1. Open `project.godot` in Godot 4.7.2.
2. Press Play. A new maze is generated on every run.
3. Use `WASD` to move and the mouse to look.
4. Press `R` to generate another maze. Find the orange light at the far end.
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