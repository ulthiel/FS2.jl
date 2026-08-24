"""
    total_number_of_small_groups(orders::AbstractVector{<:Integer})

Return the total number of groups in the GAP SmallGroups library whose orders
lie in `orders`.
"""
function total_number_of_small_groups(orders::AbstractVector{<:Integer})
    return sum(number_of_small_groups, orders; init=ZZ(0))
end
