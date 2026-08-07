"""
    galois_representatives(chars::AbstractVector{<:Oscar.GAPGroupClassFunction})

Return one representative from each Galois orbit of the characters in `chars`.
"""
function galois_representatives(
    chars::AbstractVector{<:Oscar.GAPGroupClassFunction},
)
    isempty(chars) && return Vector{eltype(chars)}()

    tbl = parent(first(chars))

    characteristic(tbl) == 0 ||
        throw(ArgumentError("only ordinary characters are supported"))

    all(chi -> parent(chi) == tbl, chars) ||
        throw(ArgumentError("all characters must belong to the same table"))

    #
    # Fast case: all characters are irreducible. Use galois_orbit_sum.
    #
    if all(is_irreducible, chars)
        reps = Vector{eltype(chars)}()
        orbit_sums = Vector{eltype(chars)}()

        for chi in chars
            s = galois_orbit_sum(chi)

            if !any(==(s), orbit_sums)
                push!(reps, chi)
                push!(orbit_sums, s)
            end
        end

        return reps
    end

    #
    # General case: use GAP's GaloisMat.
    #
    # Remove exact duplicates first, since GaloisMat otherwise prints
    # a warning and only considers the first occurrence.
    #
    distinct = Vector{eltype(chars)}()

    for chi in chars
        any(==(chi), distinct) || push!(distinct, chi)
    end

    gap_matrix = GAP.Obj([
        GAP.Globals.ValuesOfClassFunction(GapObj(chi))
        for chi in distinct
    ])

    data = GAP.Globals.GaloisMat(gap_matrix)
    families = data.galoisfams
    gap_zero = GAP.Obj(0)

    # In galoisfams, 0 denotes a non-representative member of a
    # nontrivial orbit. The entries 1, -1, or a list denote orbit
    # representatives.
    return [
        distinct[i]
        for i in eachindex(distinct)
        if families[i] != gap_zero
    ]
end

"""
    galois_representatives(tbl::Oscar.GAPGroupCharacterTable)

Return one representative from each Galois orbit of the characters in the 
character table tbl.
"""
function galois_representatives(
    tbl::Oscar.GAPGroupCharacterTable,
)
    characteristic(tbl) == 0 ||
        throw(ArgumentError("only ordinary character tables are supported"))

    return galois_representatives(collect(tbl))
end