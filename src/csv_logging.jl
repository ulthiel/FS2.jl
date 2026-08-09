# Generic CSV logging utilities for computational projects.
#
# Typical use
# -----------
#
# 1. At the beginning of a computation, create metadata shared by the whole run:
#
#     base_metadata = log_metadata(
#         packages=(oscar=Oscar, csv=CSV),
#         system=true,
#         extra=(
#             project_git_revision=git_revision(MyPackage),
#             gap_ctbllib_version=_gap_package_version("ctbllib"),
#         ),
#     )
#
# `log_metadata()` records `run_started_at_utc` and the Julia version. With
# `system=true` it also records information about the machine and Julia process,
# including the number of Julia threads. Package versions and arbitrary
# project-specific fields can be added as shown above.
#
# 2. Derive more specific metadata from the base metadata when needed:
#
#     scan_metadata = log_metadata(
#         base_metadata;
#         extra=(
#             scankind="range",
#             q=3,
#         ),
#     )
#
# The original `run_started_at_utc` and other existing metadata are preserved.
# Automatically collected metadata never overwrites existing fields, and
# `extra` is required to have disjoint field names.
#
# 3. Append computation results:
#
#     append_csv_row(
#         "results.csv",
#         (
#             group_order=189,
#             success=false,
#         );
#         metadata=scan_metadata,
#         memory=true,
#     )
#
# `append_csv_row` creates the file and parent directory if necessary, writes
# the header for a new file, and appends one row. It automatically records
# `logged_at_utc`; with `memory=true` it also records
# `process_peak_rss_bytes`.
#
# Existing CSV files are schema-checked by default: every appended row must
# have exactly the same columns in exactly the same order. Consequently, use
# options such as `memory` consistently for all rows of one log file.
#
# Writes are serialized between Julia threads and cooperating local Julia
# processes by default. The pidfile lock should not be regarded as a general
# distributed lock for several machines writing simultaneously to the same
# shared file.
#
# Values directly representable in CSV are written normally. `nothing` is
# converted to `missing`; other unsupported Julia objects are stored using
# their `show` representation.
#
# `reorder_fields(nt, order)` can be used to place selected NamedTuple fields
# first before logging while retaining all other fields in their original
# relative order.

using CSV
using Dates
using FileWatching: Pidfile
using Sockets: gethostname

const _CSV_LOG_THREAD_LOCK = ReentrantLock()
const _CSV_LOG_DATETIME_FORMAT =
    Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.s")
const _CSV_LOG_RESERVED_RECORD_COLUMNS = (
    :process_peak_rss_bytes,
    :logged_at_utc,
)

# Git metadata

"""
    git_revision(path::AbstractString)
    git_revision(mod::Module)

Return the current Git revision of the repository containing `path`, or of the
package containing `mod`.

The result has the form `"0123456789ab"` or `"0123456789ab-dirty"`.
Return `missing` if the revision cannot be determined.
"""
function git_revision(path::AbstractString)
    path = abspath(path)
    directory = isdir(path) ? path : dirname(path)

    try
        revision = readchomp(
            pipeline(
                `git -C $directory rev-parse --short=12 HEAD`,
                stderr=devnull,
            ),
        )

        status = readchomp(
            pipeline(
                `git -C $directory status --porcelain`,
                stderr=devnull,
            ),
        )

        return isempty(status) ? revision : revision * "-dirty"
    catch
        return missing
    end
end

function git_revision(mod::Module)
    root = try
        Base.pkgdir(mod)
    catch
        nothing
    end

    isnothing(root) && return missing
    return git_revision(root)
end

# Package metadata

function _module_version(mod::Module)
    version = try
        Base.pkgversion(mod)
    catch
        nothing
    end

    return isnothing(version) ? missing : string(version)
end

function _package_versions(packages::NamedTuple)
    names = Tuple(
        Symbol(string(name), "_version")
        for name in keys(packages)
    )
    versions = Tuple(
        _module_version(mod)
        for mod in values(packages)
    )

    return NamedTuple{names}(versions)
end

"""
    _gap_package_version(name::AbstractString)

Return the installed version of the GAP package `name`, or `missing` if it
cannot be determined.
"""
function _gap_package_version(name::AbstractString)
    version = try
        GAP.Globals.InstalledPackageVersion(GAP.Obj(name))
    catch
        return missing
    end

    return GAP.Globals.IsString(version) ?
        String(version) :
        missing
end

# System metadata

function _cpu_model()
    info = try
        Sys.cpu_info()
    catch
        return missing
    end

    return isempty(info) ? missing : info[1].model
end

function _system_metadata()
    return (
        hostname = gethostname(),
        pid = Int(getpid()),
        os = string(Sys.KERNEL),
        architecture = string(Sys.ARCH),
        machine = Sys.MACHINE,
        cpu_model = _cpu_model(),
        cpu_name = Sys.CPU_NAME,
        julia_cpu_target_env = get(ENV, "JULIA_CPU_TARGET", missing),
        julia_threads = Threads.nthreads(:default),
        memory_total_bytes = Sys.total_memory(),
    )
end

# Metadata construction

function _log_timestamp_utc()
    return Dates.format(
        Dates.now(Dates.UTC),
        _CSV_LOG_DATETIME_FORMAT,
    ) * "Z"
end

function _merge_defaults(
    base::NamedTuple,
    defaults::NamedTuple,
)
    names = Tuple(
        key
        for key in keys(defaults)
        if key ∉ keys(base)
    )
    values = Tuple(
        getproperty(defaults, key)
        for key in names
    )

    return merge(base, NamedTuple{names}(values))
end

function _check_no_duplicate_columns(
    left::NamedTuple,
    right::NamedTuple;
    left_name::AbstractString="first NamedTuple",
    right_name::AbstractString="second NamedTuple",
)
    duplicate_columns = Tuple(
        key
        for key in keys(left)
        if key ∈ keys(right)
    )

    isempty(duplicate_columns) ||
        throw(ArgumentError(
            "$left_name and $right_name have duplicate columns: " *
            join(string.(duplicate_columns), ", "),
        ))

    return nothing
end

"""
    log_metadata(
        [base::NamedTuple];
        packages::NamedTuple=(;),
        extra::NamedTuple=(;),
        system::Bool=false,
    )

Return metadata describing a computation run.

With no `base`, a new run is started and `run_started_at_utc` is set to the
current UTC time. With a `base`, that metadata is extended without changing its
run-start timestamp. The Julia version is added if it is not already present.

Package versions can be added with, for example,

    packages=(oscar=Oscar, csv=CSV)

which creates the columns `oscar_version` and `csv_version`. If `system=true`,
host, process, CPU, thread, and total-memory information is added. Existing
fields in `base` are never overwritten by automatically collected metadata.

`extra` adds project-specific metadata. Its fields must not duplicate fields
already present in the resulting metadata. To replace a field intentionally,
modify `base` explicitly before passing it to `log_metadata`.

Per-record fields such as `logged_at_utc` are added by `append_csv_row`.
"""
function log_metadata(
    base::Union{Nothing,NamedTuple}=nothing;
    packages::NamedTuple=(;),
    extra::NamedTuple=(;),
    system::Bool=false,
)
    metadata = if isnothing(base)
        (
            run_started_at_utc = _log_timestamp_utc(),
            julia_version = string(VERSION),
        )
    else
        _merge_defaults(base, (
            julia_version = string(VERSION),
        ))
    end

    metadata = _merge_defaults(
        metadata,
        _package_versions(packages),
    )

    if system
        metadata = _merge_defaults(
            metadata,
            _system_metadata(),
        )
    end

    _check_no_duplicate_columns(
        metadata,
        extra;
        left_name="base/automatic metadata",
        right_name="extra metadata",
    )

    return merge(metadata, extra)
end

# CSV schema and values

function _check_reserved_record_columns(
    row::NamedTuple,
    metadata::NamedTuple,
)
    reserved_columns = Tuple(
        key
        for key in _CSV_LOG_RESERVED_RECORD_COLUMNS
        if key ∈ keys(row) || key ∈ keys(metadata)
    )

    isempty(reserved_columns) ||
        throw(ArgumentError(
            "columns managed by append_csv_row may not be supplied " *
            "explicitly: " *
            join(string.(reserved_columns), ", "),
        ))

    return nothing
end

function _check_csv_schema(
    path::AbstractString,
    row::NamedTuple,
)
    existing_columns = Tuple(
        propertynames(CSV.File(path; limit=1, ntasks=1)),
    )
    new_columns = Tuple(keys(row))

    existing_columns == new_columns ||
        throw(ArgumentError(
            "CSV column mismatch for \"$path\"\n" *
            "existing columns: $(collect(existing_columns))\n" *
            "new columns:      $(collect(new_columns))",
        ))

    return nothing
end

function _append_csv_row_unlocked(
    path::AbstractString,
    row::NamedTuple;
    check_schema::Bool,
)
    new_file = !isfile(path) || filesize(path) == 0

    if !new_file && check_schema
        _check_csv_schema(path, row)
    end

    CSV.write(
        path,
        [row];
        append=!new_file,
        writeheader=new_file,
    )

    return nothing
end

_csv_value(::Nothing) = missing
_csv_value(x::Missing) = x
_csv_value(x::Union{Number,Bool,AbstractString,Dates.TimeType}) = x
_csv_value(x) = sprint(show, x)

function _csv_row(row::NamedTuple)
    return (; (key => _csv_value(value) for (key, value) in pairs(row))...)
end

# CSV logging

"""
    append_csv_row(
        path::AbstractString,
        row::NamedTuple;
        metadata::NamedTuple=(;),
        memory::Bool=false,
        use_lock::Bool=true,
        check_schema::Bool=true,
    )

Append one record to the CSV file at `path`.

The file and its parent directory are created automatically. The header is
written only when the file is new or empty. Fields from `metadata` follow the
fields from `row`.

`logged_at_utc` is added automatically after the write lock has been acquired.
If `memory=true`, `process_peak_rss_bytes` is also added. These column names are
reserved and may not occur in `row` or `metadata`. Use the same value of
`memory` for every row in a given CSV file, since it changes the schema.

If `use_lock=true`, threads and cooperating local Julia processes are
serialized through `path * ".lock"`. If `check_schema=true`, an existing file
must have exactly the same columns, in the same order, as the new record.
"""
function append_csv_row(
    path::AbstractString,
    row::NamedTuple;
    metadata::NamedTuple=(;),
    memory::Bool=false,
    use_lock::Bool=true,
    check_schema::Bool=true,
)
    _check_no_duplicate_columns(
        row,
        metadata;
        left_name="row",
        right_name="metadata",
    )
    _check_reserved_record_columns(row, metadata)

    path = abspath(path)
    mkpath(dirname(path))

    record_base = _csv_row(merge(row, metadata))

    function write_row()
        record_metadata = if memory
            (
                process_peak_rss_bytes = Sys.maxrss(),
                logged_at_utc = _log_timestamp_utc(),
            )
        else
            (
                logged_at_utc = _log_timestamp_utc(),
            )
        end

        record = merge(record_base, record_metadata)

        _append_csv_row_unlocked(
            path,
            record;
            check_schema=check_schema,
        )
    end

    if use_lock
        lock(_CSV_LOG_THREAD_LOCK) do
            Pidfile.mkpidlock(path * ".lock"; wait=true) do
                write_row()
            end
        end
    else
        write_row()
    end

    return nothing
end

# NamedTuple utilities

"""
    reorder_fields(nt::NamedTuple, order::Tuple{Vararg{Symbol}})

Return `nt` with the fields in `order` first and in the specified order. All
remaining fields retain their original relative order.
"""
function reorder_fields(
    nt::NamedTuple,
    order::Tuple{Vararg{Symbol}},
)
    length(Set(order)) == length(order) ||
        throw(ArgumentError("order contains duplicate fields"))

    unknown_fields = Tuple(
        key
        for key in order
        if key ∉ keys(nt)
    )

    isempty(unknown_fields) ||
        throw(ArgumentError(
            "unknown fields in order: " *
            join(string.(unknown_fields), ", "),
        ))

    rest = Tuple(
        key
        for key in keys(nt)
        if key ∉ order
    )
    names = (order..., rest...)
    values = Tuple(getproperty(nt, key) for key in names)

    return NamedTuple{names}(values)
end