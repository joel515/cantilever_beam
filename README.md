# Cantilever Beam Sim App

This rails application is intended to be a proof-of-concept _Sim App_ that
performs a simple rectangular cross section end- and gravity-loaded cantilever
beam finite element analysis based on the following user input:

  * Spacial dimensions (length, width, and height)
  * Material properties (elastic modulus, Poisson's ratio, and density)
  * End load
  * Mesh size

The app is intended to be a problem-specific front end for Elmer.  It utilizes
GMSH for geometry and mesh generation, ElmerGrid for mesh conversion, and
ElmerSolver for the analysis computation.

Results will be presented quantitatively and as a percent error from hand-
calculated values. Additionally, results are displaced graphically in WebGL
format via Paraview as contours of axial stress and vertical displacement.

Requirements:
  * Elmer v8.0 (including ElmerGrid and ElmerSolver)
    - With MUMPS library for direct solves.
    - With MPI libraries for parallel runs.
  * Gmsh v2.11.0
  * Paraview v.4.4.0
    - With OSMesa libraries for off-screen rendering.
    - See [here] (http://www.paraview.org/Wiki/ParaView/ParaView_And_Mesa_3D)
      for build and install instructions.

Developed by [Joel Kopp](mailto:jkopp@mkei.org) for the [Milwaukee Institute]
(https://www.mkei.org).
