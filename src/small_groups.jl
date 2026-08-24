"""
    number_of_small_groups(orders::AbstractVector{<:Integer})

Return the total number of groups in the GAP SmallGroups library whose orders
lie in `orders`.
"""
function number_of_small_groups(orders::AbstractVector{<:Integer})
    return sum(number_of_small_groups, orders; init=0)
end
