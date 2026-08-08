"""
    character_label_with_kind(
        χ::Oscar.GAPGroupClassFunction;
        short_atlas::Bool=false,
    )

Return a literature label for the irreducible character `χ`, together with the
kind of label, if one is known.

The result is a named tuple `(kind=..., label=...)`, where `kind` is one of
`:parameter`, `:deligne_lusztig`, or `:atlas`. Return `nothing` if no known
label is available.
"""
function character_label_with_kind(
    χ::Oscar.GAPGroupClassFunction;
    short_atlas::Bool=false,
)
    T = parent(χ)

    i = findfirst(==(χ), T)
    i === nothing &&
        throw(ArgumentError(
            "χ is not an irreducible character of its parent table",
        ))

    # Character parameters: partitions, generic parameters, ...
    params = try
        character_parameters(T)
    catch
        nothing
    end

    if !isnothing(params)
        return (
            kind=:parameter,
            label=params[i],
        )
    end

    gapT = GapObj(T)

    # Deligne–Lusztig names
    try
        if GAP.Globals.KnowsDeligneLusztigNames(gapT)
            names = GAP.Globals.DeligneLusztigNames(gapT)
            name = names[i]

            if GAP.Globals.IsString(name)
                return (
                    kind=:deligne_lusztig,
                    label=String(name),
                )
            end
        end
    catch
    end

    # ATLAS labels
    try
        if GAP.Globals.IsAtlasCharacterTable(gapT)
            labels = short_atlas ?
                GAP.Globals.AtlasLabelsOfIrreducibles(gapT, true) :
                GAP.Globals.AtlasLabelsOfIrreducibles(gapT)

            label = labels[i]

            if GAP.Globals.IsString(label)
                return (
                    kind=:atlas,
                    label=String(label),
                )
            end
        end
    catch
    end

    return nothing
end

"""
    character_label(
        χ::Oscar.GAPGroupClassFunction;
        short_atlas::Bool=false,
    )

Return a literature label for the irreducible character `χ` if one is known,
and `nothing` otherwise.
"""
function character_label(
    χ::Oscar.GAPGroupClassFunction;
    short_atlas::Bool=false,
)
    result = character_label_with_kind(
        χ;
        short_atlas=short_atlas,
    )

    return isnothing(result) ? nothing : result.label
end