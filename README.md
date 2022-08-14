# Wolf 3D
Demonstration of pseudo-3D first person engine for Playdate using Lua.

The goal here was to build an engine to demonstrate that something _like_ Wolfenstein 3D could reach 30fps by replacing ray-tracing with vertex-projection (I don't know how to describe this; I call it middle-out... ;-P)

It's not hitting a steady 30fps yet, but I'm optimistic.

**_Improvements/suggestions are very welcome!_** (I'm just learning how to do this).

![Wolf_working_2](https://user-images.githubusercontent.com/79881777/184538742-9b8b7a6c-8394-4648-9e85-815616f580a9.gif)

Scrappy code but the gist of it is:
* Load a simple map, where 1 = Wall block
* Create sprites for wall tiles and player in mini-map - **_the pseudo-3D all hangs off this_**
* Cast 6 rays from player from -45 degrees to +45 degrees from player direction, and use line intersection to identify viewable wall tiles
* Compare these wall sprite locations to player location to decide which 1 or 2 walls need to be drawn for each sprite
* Project the 2 or 3 vertices that describe these walls into the 3D view and make lines between them
* If vertex is behind player/camera then weird shit happens, intersect the wall with the left or right-most rays from the player and shift the vertex back to the edge of the screen view
* Make wall polygons by mirroring the projected points/lines vertically
* Sort wall polygons from nearest to furthest
* Cull polygons that are obscured by closer polygons 
* Draw wall polygons from furthest to nearest

To do:
- [X] Wall sorting
- [X] Occlusion culling
- [X] Distance shading
- [X] Implement collisions
- [ ] Fix graphical glitch when vertex is _exactly_ at 45 degrees from player (see GIF for example)
- [ ] Build sin & cos lookup tables in init (with lerp function? Or is near enough good enough?)
- [ ] Test whether predefined pattern draw faster than ditherPattern (I suspect not, but a dither LUT _might_ help a bit)
- [ ] Make the new lineSegment bits for raytrace in init and select the ones in view instead of generating new in raytrace
- [ ] Make a branch that replaces points and distances with vector2Ds so we can use vector maths and transformations, e.g. by creating view_left and view_right _once_ then rotating it to update
- [ ] Swap mini-map black wall tiles for transparent with white border (non-view) and solid transparent (in view) and remove solid background
- [ ] Clean up the code
- [ ] Implement map scrolling to allow bigger levels (infinite?)
- [ ] Replace fixed values with variables for, e.g. FOV, view distance, tile size
- [ ] Replace the 'ray casting' to identify viewable walls with simple stored tile-offset test (8 directions would be plenty)
- [ ] Add option to use 200x120 for drawing then 2x scaling for final
- [ ] Think of a better way to deal with occlusion culling because it's only ~1 or 2fps better than just drawing everything
- [ ] Implement doors (think 1 smaller wall tile + 1 sprite door + 1 smaller wall tile)
- [ ] Add demo enemies
- [ ] Running & jumping
- [ ] Shooting
- [ ] Get better hobbies
