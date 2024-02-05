"""
    move_particles!(particles, grid, args)

"""
function move_particles!(particles::AbstractParticles, grid, args)
    dxi = compute_dx(grid)
    (; coords, index) = particles
    nxi = size(index)

    @parallel (@idx nxi) move_particles_ps!(coords, grid, dxi, index, args)

    return nothing
end

@parallel_indices (I...) function move_particles_ps!(
    particle_coords, grid, dxi, index, args
)
    _move_particles!(particle_coords, grid, dxi, index, I, args)

    return nothing
end

function _move_particles!(particle_coords, grid, dxi, index, idx, args)
    # coordinate of the lower-most-left coordinate of the parent cell 
    corner_xi = corner_coordinate(grid, idx)
    # iterate over neighbouring (child) cells
    move_kernel!(particle_coords, corner_xi, dxi, index, args, idx)

    return nothing
end

function move_kernel!(
    particle_coords,
    corner_xi,
    dxi,
    index,
    args::NTuple{N2,T},
    idx::NTuple{N1,Int64},
) where {N1,N2,T}

    # iterate over particles in child cell 
    for ip in cellaxes(index)
        doskip(index, ip, idx...) && continue
        pᵢ = cache_particle(particle_coords, ip, idx)

        # check whether the particle is 
        # within the same cell and skip it
        isincell(pᵢ, corner_xi, dxi) && continue

        # new cell indices
        new_cell = get_cell(pᵢ, dxi)
        @show new_cell
        # hold particle variables
        current_args = @inbounds cache_args(args, ip, idx)
        # remove particle from child cell
        @inbounds @cell index[ip, idx...] = false
        empty_particle!(particle_coords, ip, idx)
        empty_particle!(args, ip, idx)
        # check whether there's empty space in parent cell
        free_idx = find_free_memory(index, new_cell...)
        free_idx == 0 && continue
        # move particle and its fields to the first free memory location
        @inbounds @cell index[free_idx, new_cell...] = true
        fill_particle!(particle_coords, pᵢ, free_idx, new_cell)
        fill_particle!(args, current_args, free_idx, new_cell)
    end
end