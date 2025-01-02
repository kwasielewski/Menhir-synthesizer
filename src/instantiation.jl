function replace2(input_str, replacements; extra_debug=false)
    # Initialize stack to store each level of parsing
    stack = []
    current = ""  # This will hold the current function or argument being parsed
    result = ""
    #println(replacements)
    replacements = map(x -> Pair(chop(x.first; head=1, tail=1), x.second), replacements) |> Dict
    # Process each character
    for c in input_str
        if c == '('
            #println("Current at ( ", current)
            # We're entering a function call, so push the current function/arg and start fresh
            push!(stack, current)
            push!(stack, "(")
            current = ""
        elseif c == ')'
            # We're closing a function call, so replace the deepest arguments and build the function
            #println("Current at ) ", current)
            current = strip(current)
            if haskey(replacements, current)
                #println("Replacing ", current)
                current = replacements[current]
            end

            # Pop the stack and collect all arguments inside the current function call
            args = []
            while !isempty(stack) && stack[end] != "("
                push!(args, pop!(stack))
            end
            pop!(stack)  # Remove the '('

            # Now we have the function name and arguments
            func_name = isempty(stack) ? "" : pop!(stack)
            current = func_name * "(" * join(reverse(args), "") * current * ")"
        elseif c == ','
            #println("Current at , ", current)
            current = strip(current)
            # We hit a comma, meaning an argument ends. Handle the current argument.
            if haskey(replacements, current)
                #println("Replacing ", current)
                current = replacements[current]
            end
            push!(stack, current)
            push!(stack, ",")
            current = ""  # Reset to parse next argument
        else
            # Collect characters into the current argument/function name
            current *= c
        end
    end
    current = strip(current)

    # Handle any leftover string after processing all parentheses
    if haskey(replacements, current)
        current = replacements[current]
    end
    push!(stack, current)

    # Join everything in the stack to form the final result
    return join(stack, "")
end 
function encode(s::String)
    if '(' in s && ')' in s 
        return replace(s, "(" => "3", ")" => "4", "," => "5", " " => "")
    else 
        return s
    end
end
function find_rule(rules::Vector{ProductionRule}, name)
    for r in rules
        if r.name == name
            return r
        end
    end
end
function is_fully_inst(r, fullinst)
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

function convert2triple(grammar, kwrds)
    rules = Array{ProductionRule}(undef, 0)
    i = 1
    lhs = String[]
    rhs = String[]
    productions = ProductionRule[]
    final = grammar
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
                k = j + 1
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
            k = j + 2
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
                            elseif p[i] == ')'
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
                p = map((x -> (isuppercase(x[1]) ? join(["\"", begin
                    println("x & args ", x, args)
                    (join(['"', x, '"']) in args ? x : lowercase(x))
                end, "\""]) : uppercase(x))), p)
                if length(p) == 0
                    p = ["\"\""]
                end
                p = map(x -> x[1] == '"' ? get(kwrds, chop(uppercase(x))[2:end], x) : x, p)
                push!(cur_prod.prods, Production(p))
                p = join(p, ", ")
                skip_parametrized = false
                if skip_parametrized
                    if !to_skip
                        push!(lhs, name)
                        push!(rhs, p)
                    end
                else
                    push!(lhs, name)
                    push!(rhs, p)
                end
            end
            skip_parametrized = false
            if skip_parametrized
                if !to_skip
                    push!(productions, cur_prod)
                end
            else
                push!(productions, cur_prod)
            end
            i = last_newline

        end
        fullinst = ProductionRule[]
        parametrised = ProductionRule[]
        noninst = Queue{ProductionRule}()
        for p in productions
            if length(p.args) != 0
                push!(parametrised, p)
            else

                check = y -> any(x -> '(' in x && ')' in x, y.rhs)
                if any(check, p.prods)
                    println("Enqueue noninst: ", p)
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
        shortcut = 0
        while !isempty(noninst)
            r = dequeue!(noninst)
            all_ok = is_fully_inst(r, fullinst)
            if all_ok
                continue
            end
            println("Noninst: ", r)
            pr = nothing
            for p in r.prods
                for (idx, q) in enumerate(p.rhs)
                    cnt = count(x -> x == '(', q)
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
                        extra_debug  = encode(q) == "SEPARATED_LIST3COMMA5ARITH_EXPRESSION4"

                        
                        rep = zip(pr.args, map(strip, split(chop(rule[2]), ',')))
                        rep = map(x -> Pair(x[1], String(x[2])), rep)
                        if extra_debug
                            printstyled("Found rule ", pr, "\n"; color=:red)
                            println(map(x -> Production(map(y -> replace(y, rep...), x.rhs)), pr.prods))
                            println(map(x -> Production(map(y -> replace2(replace(y, rep...), rep; extra_debug=extra_debug), x.rhs)), pr.prods))
                        end
                        println("Rep: ", rep, " ", rule, " ", q)
                        new_rule = ProductionRule(encode(q),
                            [],
                            map(x -> Production(map(y -> replace2(replace(y, rep...), rep), x.rhs)), pr.prods))
                        p.rhs[idx] = encode(q)
                        #println("is_fully_inst: ", is_fully_inst(new_rule))
                        if is_fully_inst(new_rule, fullinst) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule, fullinst)
                            println("New rules1: ", new_rule)
                            enqueue!(noninst, new_rule)
                        end
                        if extra_debug
                            println()
                        end

                    elseif cnt == 2 && '(' in q # add more latter
                        printstyled("Double inst\n"; color=:red)
                        #LOPTION(SEPARATED_NONEMPTY_LIST(COMMA, ARITH_EXPRESSION))
                        rule = split(q, '(')
                        #LOPTION SEPARATED_NONEMPTY_LIST COMMA, ARITH_EXPRESSION))
                        println("RULE ", rule)
                        pr = find_rule(parametrised, rule[2])
                        if pr isa Nothing
                            println("Error 2 ", rule[2])
                            exit(1)
                        end
                        println("found rule: ", pr)
                        argname = encode(join([rule[2], chop(rule[3])], "("))
                        rep = zip(pr.args, map(strip, split(chop(rule[3]; tail=2), ',')))
                        rep = map(x -> Pair(x[1], String(x[2])), rep)
                        new_rule = ProductionRule(argname,#encode(q),
                            [],
                            map(x -> Production(map(y -> replace2(replace(y, rep...), rep), x.rhs)), pr.prods))
                        #p.rhs[idx] = encode(q)
                        #println("is_fully_inst: ", is_fully_inst(new_rule))
                        if is_fully_inst(new_rule, fullinst) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule, fullinst)
                            println("New rules2: ", new_rule)
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


                        if is_fully_inst(new_rule, fullinst) && find_rule(fullinst, new_rule.name) isa Nothing
                            push!(fullinst, new_rule)
                        elseif !is_fully_inst(new_rule, fullinst)
                            println("New rules3: ", new_rule)
                            enqueue!(noninst, new_rule)
                        end

                    end
                end
            end
            #println("Changed rhs: ", r)
            if is_fully_inst(r, fullinst)
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
        println("Lengths ", length(fullinst), " ", length(parametrised), " ", length(noninst), " ", length(productions))

        while !isempty(noninst)
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
                ps = join(map(encode, p.rhs), ", ")
                #println(file, r.name, " = (", ps, ")")
                write(file, r.name, " = (", ps, ")\n")
            end
        end

    end
end