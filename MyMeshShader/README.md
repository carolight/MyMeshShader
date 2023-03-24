#  Mesh Shader

An attempt was made to create a mesh shader.

The future of grass is pink.

1. Render a sphere normally, showing the vertex points.

2. Pass the vertex points to an object shader.

3. The object shader creates a payload of just the vertex (not efficient, but can improve later). (The triangles on back facing vertices need to be culled.)

4. The mesh shader takes the payload and creates one pink triangle of three vertices positioned at every payload.

I expected the pink triangles to render on every vertex, but they didn't. There are 3782 vertices in the sphere.
