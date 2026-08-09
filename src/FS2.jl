module FS2

using Oscar
import Oscar: direct_product

using ProgressMeter

# No idea why this isn't in OSCAR
is_prime_power(n::Integer) = first(is_prime_power_with_data(n))

include("character_field_generation.jl")
include("character_labels.jl")
include("direct_products.jl")
include("galois_conjugacy.jl")

include("csv_logging.jl")

export character_label
export direct_product_factors
export galois_representatives
export is_direct_product
export is_fs
export is_fs_with_data
export is_fs2_with_data
export scan_ctbllib_fs2
export scan_smallgroups_fs2

end
