# Field advection in 2D

First we load JustPIC

```julia
using JustPIC
```

and the correspondent 2D module (we could also use 3D by loading `JustPIC._3D`)

```julia
using JustPIC._2D
```

We need to specify what backend are we running our simulation on. For convenience we define the backend as a constant. In this case we use the CPU backend, but we could also use the CUDA (CUDABackend) or AMDGPU (AMDGPUBackend) backends.

```julia
const backend = JustPIC.CPUBackend
```

we define an analytical flow solution to advected our particles

```julia
vx_stream(x, y) =  250 * sin(π*x) * cos(π*y)
vy_stream(x, y) = -250 * cos(π*x) * sin(π*y)
```

define the model domain

```julia
n  = 256        # number of nodes
nx = ny = n-1   # number of cells in x and y
Lx = Ly = 1.0   # domain size
xvi = xv, yv = range(0, Lx, length=n), range(0, Ly, length=n) # cell vertices
xci = xc, yc = range(0+dx/2, Lx-dx/2, length=n-1), range(0+dy/2, Ly-dy/2, length=n-1) # cell centers
dxi = dx, dy = xv[2] - xv[1], yv[2] - yv[1] # cell size
```

JustPIC uses staggered grids for the velocity field, so we need to define the staggered grid for Vx and Vy. We

```julia
grid_vx = xv, expand_range(yc) # staggered grid for Vx
grid_vy = expand_range(xc), yv # staggered grid for Vy
```

where `expand_range` is a helper function that extends the range of a 1D array by one cell size in each direction

```julia
function expand_range(x::AbstractRange)
    dx = x[2] - x[1]
    n = length(x)
    x1, x2 = extrema(x)
    xI = round(x1-dx; sigdigits=5)
    xF = round(x2+dx; sigdigits=5)
    range(xI, xF, length=n+2)
end
```

Next we initialize the particles

```julia
nxcell    = 24 # initial number of particles per cell
max_xcell = 48 # maximum number of particles per cell
min_xcell = 14 # minimum number of particles per cell
particles = init_particles(
    backend, nxcell, max_xcell, min_xcell, xvi...
)
```

and the velocity and field we want to advect (on the staggered grid)

```julia
Vx = TA(backend)([vx_stream(x, y) for x in grid_vx[1], y in grid_vx[2]]);
Vy = TA(backend)([vy_stream(x, y) for x in grid_vy[1], y in grid_vy[2]]);
T  = TA(backend)([y for x in xv, y in yv]); # defined at the cell vertices
V  = Vx, Vy;
nothing #hide
```

where `TA(backend)` will move the data to the specified backend (CPU, CUDA, or AMDGPU)

We also need to initialize the field `T` on the particles

```julia
particle_args = pT, = init_cell_arrays(particles, Val(1));
nothing #hide
```

and we can use the function `grid2particle!` to interpolate the field `T` to the particles

```julia
grid2particle!(pT, xvi, T, particles);
nothing #hide
```

we can now start the simulation

```julia
dt = min(dx / maximum(abs.(Array(Vx))),  dy / maximum(abs.(Array(Vy))));
niter = 250
for it in 1:niter
    advection!(particles, RungeKutta2(), V, (grid_vx, grid_vy), dt) # advect particles
    move_particles!(particles, xvi, particle_args)                  # move particles in the memory
    inject_particles!(particles, (pT, ), xvi)                       # inject particles if needed
    particle2grid!(T, pT, xvi, particles)                           # interpolate particles to the grid
end
```

# Pure shear in 2D

An example of two-dimensional pure shear flow is provided in this [script](https://github.com/JuliaGeodynamics/JustPIC.jl/blob/main/scripts/pureshear_ALE.jl).
The velocity field is set to:

$v_{x} = \dot{\varepsilon} x$

$v_{y} = -\dot{\varepsilon} y$

where $\dot{\varepsilon}$ is the pure shear strain rate applied at the boundaries. A positive value of $\dot{\varepsilon}$ leads to horizontal extension, while negative values correspond to horizontal compression.

The `ALE` switch (Arbitrary Lagrangian Eulerian) allows to activate, or not, model box deformation. If  `ALE=false`, the model dimension remains constant over time. If `ALE=true`, the model domain is deformed with the background pure shear rate.
  
