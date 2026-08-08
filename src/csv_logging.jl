using CSV
using Dates
using FileWatching: Pidfile

const _CSV_LOG_THREAD_LOCK = ReentrantLock()
const _CSV_LOG_DATETIME_FORMAT =
    Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.s")

"""
    git_revision(module::Module)

Return the current Git revision of the package containing `module`.

The result has the form `"0123456789ab"` or `"0123456789ab-dirty"`.
Return `missing` if the package is not in a Git checkout or Git is unavailable.
"""
function git_revision(mod::Module)
    root = try
        Base.pkgdir(mod)
    catch
        nothing
    end

    isnothing(root) && return missing

    try
        revision = readchomp(
            pipeline(
                `git -C $root rev-parse --short=12 HEAD`,
                stderr=devnull,
            ),
        )

        status = readchomp(
            pipeline(
                `git -C $root status --porcelain`,
                stderr=devnull,
            ),
        )

        return isempty(status) ? revision : revision * "-dirty"
    catch
        return missing
    end
end

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

function _cpu_model()
    info = try
        Sys.cpu_info()
    catch
        return missing
    end

    return isempty(info) ? missing : info[1].model
end

function _log_timestamp_utc()
    return Dates.format(
        Dates.now(Dates.UTC),
        _CSV_LOG_DATETIME_FORMAT,
    ) * "Z"
end

"""
    log_metadata(
        ;
        packages::NamedTuple=(;),
        extra::NamedTuple=(;),
        system::Bool=true,
        memory::Bool=true,
    )

Return metadata for computation logs.

Always includes the current UTC timestamp and Julia version. Package versions
can be added via `packages`, and arbitrary additional fields via `extra`.
Set `system=false` to omit host and CPU information, and `memory=false` to omit
memory-usage information.
"""
function log_metadata(
    ;
    packages::NamedTuple=(;),
    extra::NamedTuple=(;),
    system::Bool=false,
)
    metadata = (
        run_started_at_utc = _log_timestamp_utc(),
        julia_version = string(VERSION),
    )

    if system
        metadata = merge(metadata, (
            hostname = gethostname(),
            pid = Int(getpid()),
            os = string(Sys.KERNEL),
            architecture = string(Sys.ARCH),
            machine = Sys.MACHINE,
            cpu_model = _cpu_model(),
            cpu_target = Sys.CPU_NAME,
            cpu_threads = Sys.CPU_THREADS,
            julia_threads = Threads.nthreads(),
            memory_total_bytes = Sys.total_memory(),
        ))
    end

    return merge(
        metadata,
        _package_versions(packages),
        extra,
    )
end

function log_metadata(
    base::NamedTuple;
    extra::NamedTuple=(;),
    memory::Bool=false,
)
    metadata = (
        logged_at_utc = _log_timestamp_utc(),
    )

    if memory
        metadata = merge(metadata, (
            process_peak_rss_bytes = Sys.maxrss(),
        ))
    end

    return merge(
        base,
        extra,
        metadata,
    )
end

function _check_no_duplicate_columns(
    row::NamedTuple,
    metadata::NamedTuple,
)
    duplicate_columns = intersect(
        collect(keys(row)),
        collect(keys(metadata)),
    )

    isempty(duplicate_columns) ||
        throw(ArgumentError(
            "row and metadata have duplicate columns: " *
            join(string.(duplicate_columns), ", "),
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
_csv_value(x::Union{Number,Bool,AbstractString}) = x
_csv_value(x) = sprint(show, x)

function _csv_row(row::NamedTuple)
    return (; (key => _csv_value(value) for (key, value) in pairs(row))...)
end

"""
    append_csv_row(
        path::AbstractString,
        row::NamedTuple;
        metadata::NamedTuple=(;),
        use_lock::Bool=true,
        check_schema::Bool=true,
    )

Append one row to the CSV file at `path`.

The file and its parent directory are created automatically. The header is
written only when the file is new or empty. `metadata` is appended to `row`.

If `use_lock=true`, writers in several local Julia processes are serialized
through `path * ".lock"`. If `check_schema=true`, an existing file must have
exactly the same columns, in the same order, as the new row.
"""
function append_csv_row(
    path::AbstractString,
    row::NamedTuple;
    metadata::NamedTuple=(;),
    use_lock::Bool=true,
    check_schema::Bool=true,
)
    _check_no_duplicate_columns(row, metadata)

    path = abspath(path)
    mkpath(dirname(path))
    record = _csv_row(merge(row, metadata))

    write_row() = _append_csv_row_unlocked(
        path,
        record;
        check_schema=check_schema,
    )

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

function _gap_package_version(name::AbstractString)
    version = GAP.Globals.InstalledPackageVersion(GAP.Obj(name))

    return GAP.Globals.IsString(version) ?
        String(version) :
        missing
end

function reorder_fields(nt::NamedTuple, order::Tuple)
    rest = Tuple(k for k in keys(nt) if k ∉ order)
    names = (order..., rest...)
    return NamedTuple{names}(nt[names])
end