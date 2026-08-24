const _GNU50000_URL =
    "https://raw.githubusercontent.com/olexandr-konovalov/gnu/master/data/gnu50000.g"

function _ensure_gnu50000_loaded()
    GAP.evalstr("IsBound(gnu50000);") == true && return

    installed_file = joinpath(
        GAP.Packages.DEFAULT_PKGDIR[],
        "gnu",
        "data",
        "gnu50000.g",
    )

    if isfile(installed_file)
        data_file = installed_file
    else
        cache_dir = joinpath(GAP.Packages.DEFAULT_PKGDIR[], "fs2-data")
        mkpath(cache_dir)

        data_file = joinpath(cache_dir, "gnu50000.g")

        if !isfile(data_file)
            Downloads.download(_GNU50000_URL, data_file)
        end
    end

    GAP.Globals.Read(GapObj(data_file))

    GAP.evalstr("IsBound(gnu50000);") == true ||
        error("failed to load the Gnu group-number database")
end

"""
    number_of_groups(n::Integer)

Return the known number of isomorphism classes of groups of order `n`, using
the precomputed `gnu50000` database from the GAP Gnu project.

The database covers orders from 1 through 50000, but some entries are unknown.
The data file is loaded lazily. If it is not already available from a local Gnu
installation, FS2 downloads it on first use and caches it permanently.
"""
function number_of_groups(n::Integer)
    1 <= n <= 50000 ||
        throw(ArgumentError("order must lie between 1 and 50000"))

    _ensure_gnu50000_loaded()

    entry = GAP.Globals.gnu50000[Int(n)]
    Int(entry[1]) == n || error("corrupt gnu50000 database entry for order $n")

    value = entry[2]
    value == GAP.Globals.fail &&
        throw(ArgumentError("number of groups of order $n is not known"))

    return ZZ(BigInt(value))
end

"""
    total_number_of_small_groups(orders::AbstractVector{<:Integer})

Return the total number of groups in the GAP SmallGroups library whose orders
lie in `orders`.
"""
function total_number_of_small_groups(orders::AbstractVector{<:Integer})
    return sum(number_of_small_groups, orders; init=ZZ(0))
end
