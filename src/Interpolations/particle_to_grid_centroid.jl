## LAUNCHERS

function particle2grid_centroid!(F, Fp, xi::NTuple, particles::Particles)
    (; coords) = particles
    dxi = grid_size(xi)
    @parallel (@idx size(coords[1])) _particle2grid_centroid!(F, Fp, xi, coords, dxi)
    return nothing
end

@parallel_indices (I...) function _particle2grid_centroid!(F, Fp, xi, coords, di)
    _particle2grid_centroid!(F, Fp, I..., xi, coords, di)
    return nothing
end

## INTERPOLATION KERNEL 2D

@inbounds function _particle2grid_centroid!(
    F, Fp, inode, jnode, xi::NTuple{2,T}, p, di
) where {T}
    px, py = p # particle coordinates
    xvertex = xi[1][inode], xi[2][jnode] # centroid coordinates
    ω, ωxF = 0.0, 0.0 # init weights

    # iterate over cell
    for i in cellaxes(px)
        p_i = @index(px[i, inode, jnode]), @index(py[i, inode, jnode])
        # ignore lines below for unused allocations
        any(isnan, p_i) && continue
        ω_i = bilinear_weight(xvertex, p_i, di)
        ω += ω_i
        ωxF += ω_i * @index(Fp[i, inode, jnode])
    end

    return F[inode, jnode] = ωxF / ω
end

@inbounds function _particle2grid_centroid!(
    F::NTuple{N,T1}, Fp::NTuple{N,T2}, inode, jnode, xi::NTuple{2,T3}, p, di
) where {N,T1,T2,T3}
    px, py = p # particle coordinates
    xvertex = xi[1][inode], xi[2][jnode] # centroid coordinates
    ω, ωxF = 0.0, 0.0 # init weights

    # iterate over cell
    for i in cellaxes(px)
        p_i = @index(px[i, inode, jnode]), @index(py[i, inode, jnode])
        # ignore lines below for unused allocations
        any(isnan, p_i) && continue
        ω_i = bilinear_weight(xvertex, p_i, di)
        ω += ω_i
        ωxF = ntuple(Val(N)) do j
            Base.@_inline_meta
            muladd(ω_i, @index(Fp[j][i, inode, jnode]), ωxF[j])
        end
    end

    _ω = inv(ω)
    return ntuple(Val(N)) do i
        Base.@_inline_meta
        F[i][inode, jnode] = ωxF[i] * _ω
    end
end

## INTERPOLATION KERNEL 3D

@inbounds function _particle2grid_centroid!(
    F, Fp, inode, jnode, knode, xi::NTuple{3,T}, p, di
) where {T}
    px, py, pz = p # particle coordinates
    xvertex = xi[1][inode], xi[2][jnode], xi[3][knode] # centroid coordinates
    ω, ωF = 0.0, 0.0 # init weights

    # iterate over cell
    @inbounds for ip in cellaxes(px)
        p_i = (
            @index(px[ip, inode, jnode, knode]),
            @index(py[ip, inode, jnode, knode]),
            @index(pz[ip, inode, jnode, knode]),
        )
        isnan(p_i[1]) && continue  # ignore lines below for unused allocations
        ω_i = bilinear_weight(xvertex, p_i, di)
        ω += ω_i
        ωF = muladd(ω_i, @index(Fp[ip, inode, jnode, knode]), ωF)
    end

    return F[inode, jnode, knode] = ωF * inv(ω)
end

@inbounds function _particle2grid_centroid!(
    F::NTuple{N,T1}, Fp::NTuple{N,T2}, inode, jnode, knode, xi::NTuple{3,T3}, p, di
) where {N,T1,T2,T3}
    px, py, pz = p # particle coordinates
    xvertex = xi[1][inode], xi[2][jnode], xi[3][knode] # centroid coordinates
    ω = 0.0 # init weights
    ωxF = ntuple(i -> 0.0, Val(N)) # init weights

    # iterate over cell
    @inbounds for ip in cellaxes(px)
        p_i = (
            @index(px[ip, inode, jnode, knode]),
            @index(py[ip, inode, jnode, knode]),
            @index(pz[ip, inode, jnode, knode]),
        )
        any(isnan, p_i) && continue  # ignore lines below for unused allocations
        ω_i = bilinear_weight(xvertex, p_i, di)
        ω += ω_i
        ωxF = ntuple(Val(N)) do j
            Base.@_inline_meta
            muladd(ω_i, @index(Fp[j][ip, inode, jnode, knode]), ωxF[j])
        end
    end

    _ω = inv(ω)
    return ntuple(Val(N)) do i
        Base.@_inline_meta
        F[i][inode, jnode, knode] = ωxF[i] * _ω
    end
end
