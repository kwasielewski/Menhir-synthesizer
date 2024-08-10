#!/usr/bin/env julia

using Herb
using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret

const stdlib = false
const trim_semicolon = true

struct Production
    rhs :: Array{Symbol}
end

struct ProductionRule
    name :: Symbol
    args :: Array{Symbol}
    prods :: Array{Production}
end

function main(filename)
    file = read(filename, String)
    omit = zeros(Bool, length(file))
    preludeStart = findfirst("%{", file)[1]
    preludeStop = findfirst("%}", file)[2]
    for i in preludeStart:preludeStop
        omit[i] = true
    end

    tokensEnd = findfirst("%%", file)[1]
    omit[tokensEnd] = true
    omit[tokensEnd + 1] = true

    # remove token declarations
    i = preludeStop
    while i < tokensEnd
        lineStart = findfirst("%", file[i:tokensEnd])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        lineEnd = findfirst("\n", file[i+lineStart:tokensEnd])
        if lineEnd isa Nothing
            break
        end
        lineEnd = lineEnd[1] 
        for j in i+lineStart:i+lineStart+lineEnd
            omit[j] = true
        end
        i = i+lineStart+lineEnd
    end 

    # remove comments
    i = 1
    while i < length(file)
        lineStart = findfirst("/*", file[i:end])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        lineEnd = findfirst("*/", file[i+lineStart:end])
        if lineEnd isa Nothing
            break
        end
        lineEnd = lineEnd[1] 
        for j in i+lineStart:i+lineStart+lineEnd
            omit[j] = true
        end
        i = i+lineStart+lineEnd
    end 
   
    # remove actions
    i = 1
    while i < length(file)
        lineStart = findfirst("{", file[i:end])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        counter = 1
        lineEnd = nothing
        idx = i + lineStart + 1
        while idx < length(file)
            if file[idx] == '{'
                counter += 1
            end
            if file[idx] == '}'
                counter -= 1
            end
            if counter == 0
                lineEnd = idx
                break
            end
            idx += 1
        end
        if lineEnd isa Nothing
            break
        end
        for j in i+lineStart:lineEnd
            omit[j] = true
        end
        i = lineEnd
    end 

    # remove bindings for actions
    i = 1
    while i < length(file)
        if file[i] == '='
            omit[i] = true
            j = i - 1
            while file[j] == ' '
                omit[j] = true
                j -= 1
            end
            while file[j] !=  ' '
                omit[j] = true
                j -= 1
            end
        end
        i += 1
    end

    global trim_semicolon
    if trim_semicolon
        for (index, v) in enumerate(file)
            if v == ';'
                omit[index] = true
            end
        end
    end


    final = join([file[i] for i in 1:length(file) if omit[i] == false])
   
    global stdlib
    if stdlib
        stdlib = read("./standard.mly", String)
        final = join([final, stdlib])
    end

    final = replace(final, " \n" => "\n")
    final = replace(final, "\n\n" => "\n")
    

    println(final)

    rules = Array{ProductionRule}(undef, 0)
    i = 1
    lhs = []
    rhs = []
    open("output.txt", "w") do file
        while i < length(final)
            j = i
            while !(final[j] in ['(', ' ', ':'])
                j += 1 
            end
            name = strip(final[i:j-1]) |> uppercase
            #println(name)
            args = []
            if final[j] == '('
                k = j+1
                while final[k] != ')'
                    k += 1
                end
                args = map(x -> Symbol(strip(x)), split(final[j+1:k-1], ','))
                j = k
            end
            last_newline = nothing
            k = j+2
            while k <= length(final) && final[k] != ':'
                if final[k] == '\n'
                    last_newline = k
                end
                k += 1
            end
            if last_newline isa Nothing
                last_newline = length(final)
            end
            prods = strip(replace(final[j+2:last_newline], "\n" => " "))

            prods = map(strip, split(prods[2:end], "|"))
            for p in prods
                append!(lhs, name)
                p = split(p)
                p = map((x -> (isuppercase(x[1]) ? join(["\"", lowercase(x), "\""]) : uppercase(x))), p)
                if length(p) == 0
                    p = ["\"nothing\""]
                end
                p = join(p, ", ")
                append!(rhs, p)
                write(file, name, " = (", p, ")\n")
                #println(name, " = ", p)
            end
            #println(prods)
            i = last_newline

            #println(args)
        end
    end
    #println(lhs)
    #println(rhs)
    grammar = HerbGrammar.read_csg("output.txt")
    programs = map(x -> rulenode2expr(x, grammar), 
        collect(DFSIterator(grammar, :FILE; max_size=10, max_depth=5)))
    for p in programs
        println(p)
    end

end


main(ARGS[1])
