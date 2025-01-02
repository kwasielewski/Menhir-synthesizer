module MenhirSynth

using Herb
using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using DataStructures

include("common.jl")
include("parser.jl")
include("grammar_utils.jl")
include("instantiation.jl")
include("generator.jl")
include("pipeline.jl")

greet() = print("Hello World!!!")

end # module MenhirSynth
