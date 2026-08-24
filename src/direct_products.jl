"""
    character_table_direct_product(T1::Oscar.GAPGroupCharacterTable, T2::Oscar.GAPGroupCharacterTable)

The direct product of the character tables `T1` and `T2`.
"""
function character_table_direct_product(
    T1::Oscar.GAPGroupCharacterTable,
    T2::Oscar.GAPGroupCharacterTable
)
    p = characteristic(T1)

    characteristic(T2) == p ||
        throw(ArgumentError(
            "the tables must have the same underlying characteristic"
        ))

    gapT = GAP.Globals.CharacterTableDirectProduct(
        GapObj(T1),
        GapObj(T2),
    )

    return Oscar.GAPGroupCharacterTable(gapT, p)
end

"""
    is_direct_product(T::Oscar.GAPGroupCharacterTable)

Returns true if `T` is a direct product of character tables.
"""
function is_direct_product(T::Oscar.GAPGroupCharacterTable)
    return GAP.Globals.HasFactorsOfDirectProduct(GapObj(T))
end

"""
    direct_product_factors(T::Oscar.GAPGroupCharacterTable)

The factors of a direct product of character tables.
"""
function direct_product_factors(T::Oscar.GAPGroupCharacterTable)
    is_direct_product(T) ||
        throw(ArgumentError("character table is not a known direct product"))

    factors = GAP.Globals.FactorsOfDirectProduct(GapObj(T))
    p = characteristic(T)

    return [
        Oscar.GAPGroupCharacterTable(F, p)
        for F in factors
    ]
end

"""
    character_table_direct_product(T::Oscar.GAPGroupCharacterTable, α::Oscar.GAPGroupClassFunction, β::Oscar.GAPGroupClassFunction)

Return the external direct product `α ⊠ β` as a class function on `T`.

The character table `T` must have been constructed as the direct product of
the parent tables of `α` and `β`, in this order.
"""
function character_table_direct_product(
    T::Oscar.GAPGroupCharacterTable,
    α::Oscar.GAPGroupClassFunction,
    β::Oscar.GAPGroupClassFunction,
)
    is_direct_product(T) ||
        throw(ArgumentError("T is not a known direct product character table"))

    T1, T2 = direct_product_factors(T)

    GapObj(parent(α)) == GapObj(T1) ||
        throw(ArgumentError("α does not belong to the first factor of T"))

    GapObj(parent(β)) == GapObj(T2) ||
        throw(ArgumentError("β does not belong to the second factor of T"))

    return Oscar.class_function(T, kron(values(α), values(β)))
end
