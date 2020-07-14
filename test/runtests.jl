using InteractiveUtils, ColoredLLCodes, Test

# force ":color=>true"
Base.get(::Base.PipeEndpoint, key::Symbol, default) = key === :color ? true : default

@show Sys.ARCH

@testset "code_llvm exp(1.0)" begin
    @code_llvm exp(1.0)
end

@testset "code_llvm string(1)" begin
    @code_llvm string(1)
end

@testset "code_native exp(1.0)" begin
    @code_native exp(1.0)
end

@testset "code_native string(1)" begin
    @code_native string(1)
end

@testset "code_native syntax=:intel" begin
    if VERSION >= v"1.1"
        code_native(minmax, (Int, Int), syntax=:intel)
    else
        code_native(minmax, (Int, Int))
    end
end
