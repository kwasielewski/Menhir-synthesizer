function new_omit_array(grammar)
    return zeros(Bool, length(grammar))
end

function omit_prelude!(grammar, omit)
    preludeStart = findfirst("%{", grammar)[1]
    preludeStop = findfirst("%}", grammar)[2]
    for i in preludeStart:preludeStop
        omit[i] = true
    end
end

function omit_token_declarations!(grammar, omit)
    tokensEnd = findfirst("%%", grammar)[1]
    omit[tokensEnd] = true
    omit[tokensEnd+1] = true
    
    preludeStop = findfirst("%}", grammar)[2]
    i = preludeStop
    while i < tokensEnd
        lineStart = findfirst("%", grammar[i:tokensEnd])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        lineEnd = findfirst("\n", grammar[i+lineStart:tokensEnd])
        if lineEnd isa Nothing
            break
        end
        lineEnd = lineEnd[1]
        for j in i+lineStart:i+lineStart+lineEnd
            omit[j] = true
        end
        i = i + lineStart + lineEnd
    end
    
end

function omit_comments!(grammar, omit)
    i = 1
    while i < length(grammar)
        lineStart = findfirst("/*", grammar[i:end])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        lineEnd = findfirst("*/", grammar[i+lineStart:end])
        if lineEnd isa Nothing
            break
        end
        lineEnd = lineEnd[1]
        for j in i+lineStart:i+lineStart+lineEnd
            omit[j] = true
        end
        i = i + lineStart + lineEnd
    end
    
end

function omit_actions!(grammar, omit)
    i = 1
    while i < length(grammar)
        lineStart = findfirst("{", grammar[i:end])
        if lineStart isa Nothing
            break
        end
        lineStart = lineStart[1] - 1
        counter = 1
        lineEnd = nothing
        idx = i + lineStart + 1
        while idx < length(grammar)
            if grammar[idx] == '{'
                counter += 1
            end
            if grammar[idx] == '}'
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
    
end

function omit_action_bindings!(grammar, omit)
    i = 1
    while i < length(grammar)
        if grammar[i] == '='
            omit[i] = true
            j = i - 1
            while grammar[j] == ' '
                omit[j] = true
                j -= 1
            end
            while grammar[j] != ' '
                omit[j] = true
                j -= 1
            end
        end
        i += 1
    end
    
end

function omit_semicolons!(grammar, omit)
    for (index, v) in enumerate(grammar)
        if v == ';'
            omit[index] = true
        end
    end
    
end

function omit_marked(grammar, omit)
    return join([grammar[i] for i in 1:length(grammar) if omit[i] == false])
end

function add_stdlib(grammar)
    stdfile = read("./standard.mly", String)
    return join([grammar, stdfile])
end
    
function normalize_whitespace(grammar)
    grammar = replace(grammar, " \n" => "\n")
    return replace(grammar, "\n\n" => "\n")
end

function read_kwrds(kwrdsfile)
    kwrds = read(kwrdsfile, String) |> x -> split(x, '\n') |> x -> map((y -> map(strip, y)) ∘ split, x)
    kwrds = map(x -> [x[1], join(["\"", x[2], "\""])], kwrds) |> Dict
    return kwrds
end

function dump_grammar()

end