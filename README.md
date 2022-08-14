# Wolf_3D
Demonstration of pseudo-3D first person engine for Playdate using Lua

![Wolf_working](https://user-images.githubusercontent.com/79881777/184537441-2d21aeb9-7c30-43e4-9dd2-9ea0cea330da.gif)

Scrappy code but the gist of it is:
* Load a simple map, where 1 = Wall block
* Create sprites for wall tiles and player in mini-map - the pseudo-3D all hangs off this
* Cast 6 rays from player from -45 degrees to +45 degrees from player direction, and use line intersection to identify viewable wall tiles
* Compare these wall sprite locations to player location to decide which 1 or 2 walls need to be drawn for each sprite
* Project the 2 or 3 vertices that describe these walls into the 3D view and make lines between them
* If vertex is behind player/camera then weird shit happens, intersect the wall with the left or right-most rays from the player and shift the vertex back to the edge of the screen view
* Make wall polygons by mirroring the projected points/lines vertically
* Sort wall polygons from nearest to furthest
* Cull polygons that are obscured by closer polygons 
* Draw wall polygons from furthest to nearest

To do:
* Clean up the code
* Implement map scrolling to allow bigger levels (infinite?)
* Replace fixed values with variables for, e.g. FOV, view distance, tile size
* Replace the 'ray casting' to identify viewable walls with simple stored tile-offset test (8 directions would be plenty)
* Think of a better way to deal with occlusion culling because it's barely better than just drawing everything
* Implement doors (think 1 smaller wall tile + 1 sprite wall + 1 smaller wall tile)
* Add demo enemies
* Running & jumping
* Shooting
