# Call from root with:
# julia --project=. notebooks/counterexample-navarro-make.jl
using Oscar
using Literate

Literate.markdown(
    joinpath(@__DIR__, "counterexample-navarro.jl"),
    @__DIR__;
    execute = true,
    flavor = Literate.CommonMarkFlavor(),
)