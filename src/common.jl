struct Production
    rhs::Array{String}
end

struct ProductionRule
    name::String
    args::Array{String}
    prods::Array{Production}
end
