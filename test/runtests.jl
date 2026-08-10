using FS2
using Oscar
using Test

@testset "FS2.jl" begin
    @testset "Known FS2 failures" begin
        T = character_table("Co2")
        res, failures = is_fs2_with_data(T; q=2, findall=true)

        @test !res
        @test length(failures) == 1
        @test only(failures).α_label == raw"\\chi_{11}"

        G = small_group(189, 5)
        T = character_table(G)
        res, failures = is_fs2_with_data(T; q=3, findall=true)

        @test !res
        @test !isempty(failures)
    end
end
