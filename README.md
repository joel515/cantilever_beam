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
calculated values.  Future implementations will include a web-based Paraview
user interface.

Developed by [Joel Kopp](mailto:jkopp@mkei.org) for the [Milwaukee Institute]
(https://www.mkei.org).
