#!/usr/bin/env julia

using Herb
using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using DataStructures

const stdlib = true
const trim_semicolon = true
const skip_parametrized = false
const skip_to_gen = false

struct Production
    rhs :: Array{String}
end

struct ProductionRule
    name :: String
    args :: Array{String}
    prods :: Array{Production}
end

example = nothing

function main(filename, kwrdsfile)

    #----------Grammmar parsing---------------
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
        stdfile = read("./standard.mly", String)
        final = join([final, stdfile])
    end

    final = replace(final, " \n" => "\n")
    final = replace(final, "\n\n" => "\n")
    

    println(final)

    #------Herb grammar output--------
    println(read(kwrdsfile, String))
    kwrds = read(kwrdsfile, String) |> x -> split(x, '\n') |> x -> map((y -> map(strip, y)) ∘ split, x)
    println(kwrds)
    kwrds = map(x -> [x[1], join(["\"", x[2], "\""])], kwrds) |> Dict

    
    rules = Array{ProductionRule}(undef, 0)
    i = 1
    lhs = String[]
    rhs = String[]
    productions = ProductionRule[]
    open("output.txt", "w") do file
        while i < length(final)
            j = i
            while !(final[j] in ['(', ' ', ':'])
                j += 1 
            end
            to_skip = final[j] == '('
            name = strip(final[i:j-1]) |> uppercase
            #println(name)
            args = []
            if final[j] == '('
                k = j+1
                while final[k] != ')'
                    k += 1
                end
                args = map(x -> strip(x), split(final[j+1:k-1], ','))
                j = k
            end
            args = map(uppercase, args)
            args = map(x -> join(['"', x, '"']), args)
            cur_prod = ProductionRule(name, args, [])
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
                function split_paren(p)
                    res = String[]
                    balance = 0
                    start = 1
                    i = 1
                    while i <= length(p)
                        start = i 
                        while i < length(p) && (balance != 0 || p[i] != ' ')  
                            if p[i] == '('
                                balance += 1
                            elseif  p[i] == ')'
                                balance -= 1
                            end
                            i += 1
                        end
                        #println(p[start:i])
                        txt = strip(p[start:i])
                        if txt != ""
                            push!(res, txt)
                        end
                        i += 1
                    end
                    return res
                end
                #println(p)
                p = split_paren(p)#split(p) #problem with parametrized rules
                println(p)
                #exit(0)
                #println(name, " ", args)
                p = map((x -> (isuppercase(x[1]) ? join(["\"", begin println("x & args ", x, args); (join(['"', x, '"']) in args ? x : lowercase(x)) end, "\""]) : uppercase(x))), p)
                if length(p) == 0
                    p = ["\"\""]
                end
                p = map(x -> x[1] == '"' ? get(kwrds, chop(uppercase(x))[2:end], x) : x, p)
                push!(cur_prod.prods, Production(p))
                p = join(p, ", ")
                global skip_parametrized
                if skip_parametrized
                    if !to_skip
                        push!(lhs, name)
                        push!(rhs, p)
                        #push!(productions, cur_prod)
                        #write(file, name, " = (", p, ")\n")
                    end
                else
                    push!(lhs, name)
                    push!(rhs, p)
                    #push!(productions, cur_prod)
                    #write(file, name, " = (", p, ")\n")
                end
                #println(name, " = ", p)
            end
            if skip_parametrized
                if !to_skip
                    push!(productions, cur_prod)
                end
            else
                push!(productions, cur_prod)
            end
            #println(prods)
            i = last_newline

            #println(args)
        end
        #=
        for l in lhs
            println(l)
        end
        println()
        for r in rhs 
            println(r)
        end
        println()
        for p in productions
            println(p)
        end
        =#
        fullinst = ProductionRule[]
        parametrised = ProductionRule[]
        noninst = Queue{ProductionRule}()
        for p in productions 
            if length(p.args) != 0
                push!(parametrised, p)
            else
                
                check = y -> any(x -> '(' in x && ')' in x, y.rhs)
                if any(check, p.prods)
                    enqueue!(noninst, p)
                else 
                    push!(fullinst, p)
                end
            end
        end
        
        println("Fullinst")
        for p in fullinst
            println(p)
        end
        println()
        println("Parametrised")
        for p in parametrised
            println(p)
        end
        if !isempty(noninst)
            println(first(noninst))
        end
        
        println(length(fullinst), " ", length(parametrised), " ", length(productions))
        function encode(s::String)
            return replace(s, "(" => "3", ")" => "4", "," => "5", " " => "")
        end
        function find_rule(rules::Vector{ProductionRule}, name)
            for r in rules
                if r.name == name
                    return r
                end
            end
        end
        function is_fully_inst(r)
            all_ok = true
            for p in r.prods
                for q in p.rhs
                    if '(' in q && ')' in q
                        encoded = encode(q)
                        if !any(x -> x.name == encoded, fullinst)
                            all_ok = false
                        end
                    elseif '3' in q && '4' in q
                        if !any(x -> x.name == q, fullinst)
                            #all_ok = false
                        end
                    end
                end
            end
            return all_ok
        end
        shortcut = 0
        #ProductionRule("LABELED", String[], Production[Production(["MANY1(LABELED_STATEMENT)"])])
        #ProductionRule("MANY1", ["P"], Production[Production(["\"P\"", "MANY(P)"])])
        function replace2(s, rep)
            if ! ('(' in s && ')' in s)
                return s
            end
            s = split(chop(s), '(')
            args = split(s[2], ',')
            rep = map(x -> Pair(chop(x.first; head=1, tail=1), x.second), rep)
            args = map(x -> x, replace(args, rep...))
            return (join([s[1], '(', (join(args, ',')), ')']))
        end
        while ! isempty(noninst)
            r = dequeue!(noninst)
            all_ok = is_fully_inst(r)
            if all_ok
                continue
            end
            println(r)
            pr = nothing
            for p in r.prods
                for (idx, q) in enumerate(p.rhs)
                    cnt = count(x -> x =='(', q)
                    #LOPTION(SEPARATED_NONEMPTY_LIST(COMMA, ARITH_EXPRESSION))
                    if cnt == 1 && ')' in q
                        rule = split(q, '(')
                        #println(rule)
                        pr = find_rule(parametrised, rule[1])
                        if pr isa Nothing
                            println("Error ", rule[1])
                            exit(1)
                        end
                        #println(pr)
                        rep = zip(pr.args, map(strip, split(chop(rule[2]), ',')))
                        rep = map(x -> Pair(x[1], String(x[2])), rep)
                        println("Rep: ", rep, " ", rule)
                        new_rule = ProductionRule(encode(q),
                                                                  [],
                                                                  map(x -> Production(map(y -> replace2(replace(y, rep...), rep), x.rhs)), pr.prods))
                        p.rhs[idx] = encode(q)
                        #println("is_fully_inst: ", is_fully_inst(new_rule))
                        if is_fully_inst(new_rule) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule)
                            println("New rules: ", new_rule)
                            enqueue!(noninst, new_rule)
                        end

                    elseif cnt == 2 && '(' in q # add more latter
                        #LOPTION(SEPARATED_NONEMPTY_LIST(COMMA, ARITH_EXPRESSION))
                        rule = split(q, '(')
                        #LOPTION SEPARATED_NONEMPTY_LIST COMMA, ARITH_EXPRESSION))
                        #println(rule)
                        pr = find_rule(parametrised, rule[2])
                        if pr isa Nothing
                            println("Error 2 ", rule[2])
                            exit(1)
                        end
                        #println(pr)
                        argname = encode(join([rule[2], chop(rule[3])], "("))
                        rep = zip(pr.args, map(strip, split(chop(rule[3]; tail=2), ',')))
                        rep = map(x -> Pair(x[1], String(x[2])), rep)
                        new_rule = ProductionRule(argname,#encode(q),
                                                                  [],
                                                                  map(x -> Production(map(y -> replace2(replace(y, rep...), rep), x.rhs)), pr.prods))
                        #p.rhs[idx] = encode(q)
                        #println("is_fully_inst: ", is_fully_inst(new_rule))
                        if is_fully_inst(new_rule) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule)
                            println("New rules: ", new_rule)
                            enqueue!(noninst, new_rule)
                        end

                        pr = find_rule(parametrised, rule[1])
                        if pr isa Nothing
                            println(rule[1])
                            exit(1)
                        end
                        #println(pr)
                        rep = zip(pr.args, [argname])
                        rep = map(x -> Pair(x[1], String(x[2])), rep)
                        new_rule = ProductionRule(encode(q),
                                                                  [],
                                                                  map(x -> Production(map(y -> replace2(replace(y, rep...), rep), x.rhs)), pr.prods))
                        
                        
                        if is_fully_inst(new_rule) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule)
                            println("New rules: ", new_rule)
                            enqueue!(noninst, new_rule)
                        end
                        
                    end
                end
            end
            #println("Changed rhs: ", r)
            if is_fully_inst(r)
                push!(fullinst, r)
            else
                enqueue!(noninst, r)
            end

            shortcut += 1
            if shortcut > 100
                break
            end
            #instantiate required rules

        end
        println()
        println()
        println("Lengths ", length(fullinst), " ", length(parametrised), " ", length(noninst), " ",length(productions))

        while ! isempty(noninst)
            r = dequeue!(noninst)
            println(r.name)
            println(r.args)
            for p in r.prods
                println(p)
            end
            println()
        end
        println()
        
        for r in fullinst
            #println(r)
            for p in r.prods
                #ps = join(map(x -> join([x, ","]), p.rhs), " ")
                ps = join( p.rhs, ", ")
                #println(file, r.name, " = (", ps, ")")
                write(file, r.name, " = (", ps, ")\n")
            end
        end 
        
    end
    #exit(1)

    #----------Generating programs---------------

    #println(lhs)
    #println(rhs)
    grammar = HerbGrammar.read_csg("output1.txt")
    println(grammar)
    #programs = map(x -> rulenode2expr(x, grammar), 
    #    collect(DFSIterator(grammar, :FILE; max_size=20, max_depth=20)))
    function toString(e)
        if e isa Vector #&& e.head == :tuple
            return join(map(toString, e), " ")
        elseif e isa String && e != "eof"
            return e
        else
            return ""
        end
    end
    
    ident = [0]
    function newId()
        ident[1] += 1
        return join(["a", string(ident[1])])
    end
    function toVec(e)
        e = collect(Any, e)
        for i in 1:length(e)
            if e[i] isa Expr && e[i].head == :tuple 
                e[i] = toVec(e[i].args)
            end
        end
        return e
    end
    function instantiate(e, funs, ctx)
        if e isa Vector
            oldctx = ctx
            if e[1] == "{"
                ctx = copy(ctx)
            end
            if length(e) >= 2
                if e[1] == "identifier" && e[2] == "="
                    e[1] = newId()
                    push!(ctx, e[1])
                end
                if e[1] == "val" || e[1] == "res"
                    e[2] = newId()
                    push!(ctx, e[2])
                end
                if e[1] == "function"
                    e[2] = newId()
                    push!(funs, e[2])
    
                end
                if e[1] == "call"
                    e[2] = rand(funs)
                end
            end
            for i in 1:length(e)
                if e[i] isa Vector
                    e[i], funs, ctx = instantiate(e[i], funs, ctx)
                end
                if e[i] == "identifier"
                    e[i] = rand(ctx)
                end
            end
            if e[end] ==  "}"
                return e, funs, oldctx
            end
            return e, funs, ctx
        else
            return e, funs, ctx
        end
    end
    println()
    println()
    cnt = 0
    for p in BFSIterator(grammar, :FILE; max_size=100, max_depth=100)
        ident[1] = 0
        e = rulenode2expr(p, grammar)
        println(e)
        e = toVec(e.args)
        #println(e)
        #println(instantiate(e, [], []))
        println(toString(instantiate(e, [], [])[1]))
        println()
        if cnt > 200
            break
        end
        if cnt == 0
            global example
            example = e
        end
        cnt += 1
    end
    #for p in programs
    #    println(p)
    #    println(toString(p))
    #    println()
    #end
    #global example
    #if length(programs) > 0
    #    example = programs[1]
    #end
end


main(ARGS[1], ARGS[2])
