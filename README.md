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
5. The Howler should have better noise detection to follow/stalk the player better.
6. A win state; when getting to the ending a message showing that you've exited the backrooms.