module CharacterLab

using Oscar
import Oscar: direct_product

using ProgressMeter


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
export is_fs2
export scan_ctbllib_fs2

end
