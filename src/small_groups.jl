"""
    total_number_of_small_groups(orders::AbstractVector{<:Integer})

Return the total number of groups in the GAP SmallGroups library whose orders
lie in `orders`.

This deliberately uses only `number_of_small_groups`. Broader databases of
known values of the number of groups of a given order are currently fragmented
and may contain stale or inconsistent data, so FS2 does not provide a wrapper
for them.
"""
function total_number_of_small_groups(orders::AbstractVector{<:Integer})
    return sum(number_of_small_groups, orders; init=ZZ(0))
end
