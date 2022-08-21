# Wolf 3D
Demonstration of pseudo-3D first person engine for Playdate using Lua.

The goal here was to build an engine to demonstrate that something _like_ Wolfenstein 3D could reach 30fps by replacing ray-tracing with vertex-projection (I don't know how to describe this; I call it middle-out... ;-P)

**_Improvements/suggestions are very welcome!_** (I'm just learning how to do this).

![Wolf_shooting](https://user-images.githubusercontent.com/79881777/185771654-cc1e56f0-368f-46d5-8161-6e0ebb3366f7.gif)


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
- [X] ~~Wall sorting~~ done but now removed as unnecessary
- [X] ~~Occlusion culling~~ done but now removed as unnecessary
- [X] Distance shading
- [X] Implement collisions
- [X] Fix graphical glitch when vertex is _exactly_ at 45 degrees from player (see GIF for example)
- [ ] Build sin & cos lookup tables in init (with lerp function? Or is near enough good enough?)
- [X] Test whether predefined pattern draw faster than ditherPattern (Nope)
- [X] Make the new lineSegment bits for raytrace in init and rotate them instead of generating new in raytrace
- [ ] Make a branch that replaces points and distances with vector2Ds so we can use vector maths and transformations, e.g. by creating view_left and view_right _once_ then rotating it to update
- [ ] Clean up the code
- [ ] Implement map scrolling to allow bigger levels (infinite?)
- [X] Replace fixed values with variables for, e.g. FOV, view distance, tile size
- [ ] Replace the 'ray casting' to identify viewable walls with simple stored tile-offset test (8 directions would be plenty)
- [ ] Add option to use 200x120 for drawing then 2x scaling for final
- [X] Think of a better way to deal with occlusion culling because it's only ~1 or 2fps better than just drawing everything
- [ ] Implement doors (think 1 smaller wall tile + 1 sprite door + 1 smaller wall tile)
- [ ] Add demo enemies
- [ ] Running & jumping
- [X] Shooting
- [ ] Get better hobbies
