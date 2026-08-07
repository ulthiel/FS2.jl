"""
    character_label(chi; short_atlas=false, fallback=false, details=false)

Return the best available label for an irreducible character `chi`.

The preferred label is selected in this order:

1. ATLAS label;
2. Deligne–Lusztig name;
3. character parameter;
4. a non-default `CharacterNames` entry;
5. AtlasRep's degree-letter name.

The default GAP names `"X.1"`, `"X.2"`, ... are not regarded as
meaningful labels.

If `fallback=true`, return `"table_identifier[row]"` when no genuine
label is available.

If `details=true`, return a named tuple containing all labels found,
rather than only the preferred label.
"""
function character_label(
    chi::Oscar.GAPGroupClassFunction;
    short_atlas::Bool = false,
    fallback::Bool = false,
    details::Bool = false,
)
    T = parent(chi)
    irr = collect(T)

    row = findfirst(==(chi), irr)
    row === nothing &&
        throw(ArgumentError(
            "the character is not an irreducible row of its parent table"
        ))

    gapT = GapObj(T)
    gapchi = GapObj(chi)

    # Convert an arbitrary GAP object to its GAP string representation.
    gap_string(x) = String(GAP.Globals.String(x))

    #
    # 1. ATLAS / Modular ATLAS label
    #
    atlas_label = nothing

    if is_atlas_character_table(T)
        labels = if short_atlas
            GAP.Globals.AtlasLabelsOfIrreducibles(gapT, true)
        else
            GAP.Globals.AtlasLabelsOfIrreducibles(gapT)
        end

        atlas_label = String(labels[row])
    end

    #
    # 2. Deligne–Lusztig name
    #
    # KnowsDeligneLusztigNames must be checked first.  Calling
    # DeligneLusztigName blindly can produce the error you observed.
    #
    deligne_lusztig_label = nothing

    if characteristic(T) == 0 &&
       (GAP.Globals.KnowsDeligneLusztigNames(gapT)::Bool)

        name = GAP.Globals.DeligneLusztigName(gapchi)

        if name != GAP.Globals.fail
            deligne_lusztig_label = gap_string(name)
        end
    end

    #
    # 3. Character parameter
    #
    # OSCAR removes the auxiliary generic-table type component when
    # possible.  For Sym(n), for example, this gives the partition itself.
    #
    parameters = character_parameters(T)

    character_parameter =
        parameters === nothing ? nothing : parameters[row]

    character_parameter_label =
        character_parameter === nothing ? nothing :
        string(character_parameter)

    #
    # 4. Explicit CharacterNames entry
    #
    # Discard the generic default "X.i".
    #
    names = GAP.Globals.CharacterNames(gapT)
    raw_character_name = String(names[row])

    character_name =
        raw_character_name == "X.$row" ? nothing : raw_character_name

    #
    # 5. AtlasRep degree-letter name, such as "3a" or "3b"
    #
    # AtlasCharacterNames belongs to AtlasRep rather than CTblLib, so
    # first check whether the global function is available.
    #
    atlasrep_name = nothing

    atlasrep_available =
        GAP.Globals.IsBoundGlobal(
            GAP.Obj("AtlasCharacterNames")
        )::Bool

    if atlasrep_available
        ordinary_T =
            characteristic(T) == 0 ? T : ordinary_table(T)

        if is_simple(ordinary_T)
            atlasrep_names =
                GAP.Globals.AtlasCharacterNames(gapT)

            atlasrep_name = String(atlasrep_names[row])
        end
    end

    #
    # Choose the preferred label.
    #
    candidates = (
        (:atlas, atlas_label),
        (:deligne_lusztig, deligne_lusztig_label),
        (:character_parameter, character_parameter_label),
        (:character_name, character_name),
        (:atlasrep, atlasrep_name),
    )

    label = nothing
    source = :none

    for (candidate_source, candidate_label) in candidates
        if candidate_label !== nothing
            label = candidate_label
            source = candidate_source
            break
        end
    end

    if label === nothing && fallback
        label = "$(identifier(T))[$row]"
        source = :table_row
    end

    info = (
        label = label,
        source = source,
        table = identifier(T),
        row = row,
        atlas_label = atlas_label,
        deligne_lusztig_label = deligne_lusztig_label,
        character_parameter = character_parameter,
        character_parameter_label = character_parameter_label,
        character_name = character_name,
        atlasrep_name = atlasrep_name,
    )

    return details ? info : label
end