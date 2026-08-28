using FS2
using Oscar
using Test

@testset "FS2.jl" begin
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
