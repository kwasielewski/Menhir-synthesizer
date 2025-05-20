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
function consumeId(toUse)
  if length(toUse) > 0
        id = toUse[1]
        pop!(toUse)
        return id
    end
    newId()
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
function instantiate(e, toUse, funs, ctx)
    if e isa Vector
        oldctx = ctx
        if e[1] == "{"
            ctx = copy(ctx)
        end
        lhs = nothing
        if length(e) >= 2
            if e[1] == "identifier" && e[2] == "="
                e[1] = consumeId(toUse)
                lhs = e[1]
                #push!(ctx, e[1])
            end
            if e[1] == "val"
                e[2] = newId()
                push!(ctx, e[2])
            end
            if e[1] == "res"
                e[2] = newId()
                push!(toUse, e[2])
            end
            if e[1] == "function" && e[2] != "main"
                e[2] = newId()
                push!(funs, e[2])

            end
            if e[1] == "call"
                e[2] = rand(funs)
            end
        end
        for i in 1:length(e)
            if e[i] isa Vector
                e[i], funs, ctx = instantiate(e[i], toUse, funs, ctx)
            end
            if e[i] == "identifier"
                if length(ctx) == 0
                    e[i] = string(mod(Random.rand(Int), 10))
                else
                    e[i] = rand(ctx)
                end
            end
            if e[i] == "int"
                e[i] = string(mod(Random.rand(Int), 10))
            end
        end
        if !isnothing(lhs)
            push!(ctx, lhs)
        end
        if e[end] == "}"
            return e, funs, oldctx
        end
        return e, funs, ctx
    else
        return e, funs, ctx
    end
end


function stdout_generation(grammar)
    cnt = 0
    for p in BFSIterator(grammar, :FILE; max_size=100, max_depth=100)
        ident[1] = 0
        e = rulenode2expr(p, grammar)
        println(e)
        e = toVec(e.args)
        #println(e)
        #println(instantiate(e, [], []))
        println(toString(instantiate(e, [], [], [])[1]))
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

end

function directory_generation(grammar;ppb=false)
    cnt = 0
    name = "progs_" * string(now())
    mkdir("results/" * name)
    if ppb
        it = MLFSIterator(grammar, :FILE; max_size=400, max_depth=200)
    else
        it = BFSIterator(grammar, :FILE; max_size=100, max_depth=100)
    end
    for p in it 
        ident[1] = 0
        e = rulenode2expr(p, grammar)
        println(e)
        e = toVec(e.args)
        #println(e)
        #println(instantiate(e, [], []))
        program = toString(instantiate(e, [], [], [])[1])
        println(program)
        println()
        open("results/" * name * "/" * string(cnt) * ".proc", "w") do file
            write(file, program) 
        end
        if cnt > 10000
            break
        end
        if cnt == 0
            global example
            example = e
        end
        cnt += 1
    end

end
