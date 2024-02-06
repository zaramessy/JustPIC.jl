@inline _interp1D(xq, x0, x1, y0, y1) = fma((xq - x0), (y1 - y0) * inv(x1 - x0), y0)

function interp1D_extremas(xq, x, y)
    x_lo, x_hi = x[1], x[end]
    @inbounds for j in eachindex(x)[1:(end - 1)]
        x0, x1 = x[j], x[j + 1]

        # interpolation
        if x0 < xq < x1
            y0, y1 = y[j], y[j + 1]
            return _interp1D(xq, x0, x1, y0, y1)
        end

        # extrapolation
        if xq < x_lo
            x0, x1 = x[1], x[2]
            y0, y1 = y[1], y[2]
            return _interp1D(xq, x0, x1, y0, y1)
        end

        if xq > x_hi
            x0, x1 = x[end], x[end - 1]
            y0, y1 = y[end], y[end - 1]
            return _interp1D(xq, x0, x1, y0, y1)
        end
    end
    error("xq outside domain")
end

function interp1D_inner(xq, x, y, cell_coords, I::Integer)
    x_lo, x_hi = x[1], x[end]
    @inbounds for j in eachindex(x)[1:(end - 1)]
        x0, x1 = x[j], x[j + 1]

        # interpolation
        if x0 < xq < x1
            y0, y1 = y[j], y[j + 1]
            return _interp1D(xq, x0, x1, y0, y1)
        end

        # interpolate using the last particle of left-neighbouring cell
        if xq < x_lo
            x0, y0 = left_cell_right_particle(cell_coords, I)
            x1, y1 = x[1], y[1]
            return _interp1D(xq, x0, x1, y0, y1)
        end
        # interpolate using the first particle of right-neighbouring cell
        if xq > x_hi
            x0, y0 = x[end], y[end]
            x1, y1 = right_cell_left_particle(cell_coords, I)
            return _interp1D(xq, x0, x1, y0, y1)
        end
    end
    error("xq outside domain")
end


@inline right_cell_left_particle(cell_coords, I::Int) = @cell(cell_coords[1][1, I+1]), @cell(cell_coords[2][1, I+1])

@inline function left_cell_right_particle(cell_coords, I)
    px = cell_coords[1][I-1]
    ip = findlast(!isnan, px)
    return px[ip], @cell(cell_coords[2][ip, I-1])
end

@inline function is_above_surface(xq, yq, coords, cell_vertices)
    I = cell_index(xq, cell_vertices)
    x_cell, y_cell = coords[1][I], coords[2][I]
    return yq > interp1D_inner(xq, x_cell, y_cell, coords, I)
end