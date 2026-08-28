using FS2
using Oscar
using Test

@testset "FS2.jl" begin
    @testset "Conductor attainment" begin
        # Linear characters attain their entire character field at an image
        # generator. Rational characters (including the trivial one) have
        # conductor 1, attained at every value, including zero.
        for G in (cyclic_group(1), cyclic_group(6), abelian_group([2, 4]),
                  symmetric_group(3))
            @test is_cs(G)
        end
        T = character_table(cyclic_group(6))
        χ = first(χ for χ in T if is_faithful(χ))
        # Q(zeta_6) = Q(zeta_3): root order is not the conductor.
        @test conductor(χ) == 3
        @test is_cs(χ)

        # Thiel, arXiv:2608.02266v1, §2: SmallGroup(32,15) fails FS.
        # CS nevertheless holds for every 2-group: the value conductors are
        # powers of 2, so their lcm is their maximum and is attained.
        T = character_table(small_group(32, 15))
        χ = first(χ for χ in T if !is_fs(χ))
        @test is_cs(χ)
        @test is_cs(T)

        # Thiel, arXiv:2608.02266v1, §2 records this CS counterexample.
        G = small_group(960, 730)
        T = character_table(G)
        @test !is_cs(T)
        @test !is_cs(G)
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
