using FS2
using Oscar
using Test
using FS2: CSV

@testset "FS2.jl" begin
    @testset "Field generation and conductor attainment" begin
        # Linear characters attain their entire character field at an image
        # generator. Rational characters (including the trivial one) have
        # conductor 1, attained at every value, including zero.
        for G in (cyclic_group(1), cyclic_group(6), abelian_group([2, 4]),
                  symmetric_group(3))
            @test is_fs(character_table(G))
            @test is_fs(G)
            @test is_cs(G)
            @test is_fs_with_data(G) == (true, NamedTuple[])
            @test is_cs_with_data(G) == (true, NamedTuple[])
        end
        T = character_table(cyclic_group(6))
        χ = first(χ for χ in T if is_faithful(χ))
        # Q(zeta_6) = Q(zeta_3): root order is not the conductor.
        @test conductor(χ) == 3
        @test is_cs(χ)
        @test is_cs_with_data(χ) == (true, (char_conductor=3, max_value_conductor=3))

        # Thiel, arXiv:2608.02266v1, §2: SmallGroup(32,15) fails FS.
        # CS nevertheless holds for every 2-group: the value conductors are
        # powers of 2, so their lcm is their maximum and is attained.
        G = small_group(32, 15)
        T = character_table(G)
        @test !is_fs(T)
        @test !is_fs(G)
        @test is_fs2(G) # FS must also test the even-degree, non-2-rational characters.
        χ = first(χ for χ in T if !is_fs(χ))
        @test is_cs(χ)
        @test is_cs(T)

        # Thiel, arXiv:2608.02266v1, §2 records this CS counterexample.
        G = small_group(960, 730)
        T = character_table(G)
        @test !is_cs(T)
        @test !is_cs(G)
    end

    @testset "Attainment diagnostics and logging" begin
        # Known failures: Thiel, arXiv:2608.02266v1, §2. The CS example is
        # also in Boltje et al., arXiv:2507.19618v1, §9 (after Theorem 9.6).
        for (test_data, group_id) in ((is_fs_with_data, (32, 15)),
                                      (is_cs_with_data, (960, 730)))
            G = small_group(group_id...)
            res, group_failures = test_data(G; findall=true)
            @test !res
            @test !isempty(group_failures)

            # Tensoring a failing character with each of the two rational
            # characters of C2 preserves its value fields/conductors and
            # gives distinct Galois orbits. Thus at least two failures must
            # be found, making findall and early stopping distinguishable.
            T = character_table_direct_product(character_table(G), character_table(cyclic_group(2)))
            res, failures = test_data(T; findall=true)
            @test !res
            @test length(failures) >= 2
            @test test_data(T) == (false, failures[1:1])
            @test length(unique(f.χ_position for f in failures)) == length(failures)
            for f in failures
                χ = T[f.χ_position]
                @test f.χ_label == character_label(χ)
                @test f.χ_degree == degree(ZZRingElem, χ)
                @test f.χ_conductor == conductor(χ)
                res, data = test_data(χ)
                @test !res
                if test_data === is_fs_with_data
                    @test f.χ_char_field_degree == data.char_field_degree
                    @test f.χ_max_value_degree == data.max_value_degree
                else
                    @test f.χ_conductor == data.char_conductor
                    @test f.χ_max_value_conductor == data.max_value_conductor
                end
            end

            mktempdir() do dir
                findings = joinpath(dir, "findings.csv")
                scan = joinpath(dir, "scan.csv")
                for findall in (false, true)
                    @test test_data(T; findall=findall, table_label="example",
                        findings_log_file=findings, scan_log_file=scan,
                        metadata=(run="test",)) == (false, findall ? failures : failures[1:1])
                end
                @test test_data(character_table(cyclic_group(1));
                    findings_log_file=findings, scan_log_file=scan,
                    metadata=(run="test",)) == (true, NamedTuple[])
                rows = CSV.File(findings)
                @test length(rows) == 1 + length(failures)
                @test all(r -> r.table == "example" && r.run == "test", rows)
                @test rows.χ_position == [first(failures).χ_position; getproperty.(failures, :χ_position)]
                scans = CSV.File(scan)
                @test scans.false_characters == [1, length(failures), 0]
                @test scans.findall == [false, true, false]
                @test scans.G_order == [2 * group_id[1], 2 * group_id[1], 1]
            end
            @test_throws MethodError test_data(T; q=2)
            @test_throws ArgumentError test_data(character_table(symmetric_group(3), 2))
        end
    end

    @testset "SmallGroups CS scan" begin
        mktempdir() do dir
            # Orders 4 and 5 are skipped because they are prime powers. There
            # are exactly two groups of order 6, both of which satisfy FS and
            # hence CS (C6 is abelian and S3 is rational).
            @test scan_smallgroups_cs(
                4:6;
                show_progress=false,
                log_dir=dir,
                metadata=(run="test",),
            ) === nothing

            scan_dir = joinpath(dir, "smallgroups-4-6-cs-findall")
            @test !isfile(joinpath(scan_dir, "findings.csv"))
            rows = CSV.File(joinpath(scan_dir, "scan.csv"))
            @test length(rows) == 2
            @test rows.false_characters == [0, 0]
            @test rows.scan_index == [1, 2]
            @test rows.scan_total == [2, 2]
            @test rows.G_order == [6, 6]
            @test all(r -> r.scan_id == "smallgroups-4-6-cs-findall", rows)
            @test all(r -> r.run == "test", rows)
        end

        @test_throws MethodError scan_smallgroups_cs(4:6; q=2)
    end

    @testset "Group shortcut" begin
        # Every irreducible character of a finite abelian group is linear.
        # Its image is cyclic, so one value generates its character field;
        # this also applies after taking a direct product with C_{q^2}.
        for G in (cyclic_group(1), cyclic_group(3), abelian_group([2, 4]))
            @test is_fs2(G)
            @test is_fs2(G; q=2)
        end
        @test_throws ArgumentError is_fs2(cyclic_group(1); q=6)
    end

    @testset "Known FS2 failures" begin
        T = character_table("Co2")
        res, failures = is_fs2_with_data(T; q=2, findall=true)

        @test !res
        @test length(failures) == 1
        @test only(failures).α_label == "\\chi_{22}"

        G = small_group(189, 5)
        T = character_table(G)
        res, failures = is_fs2_with_data(T; q=3, findall=true)

        @test !res
        @test !isempty(failures)
        @test !is_fs2(G; q=3)

        G = small_group(567, 36)
        T = character_table(G)

        @test !is_fs2(T)
        @test !is_fs2(G)
    end
end
