"""
    run(filename, kwrdsfile)

Run the complete code synthesis pipeline based on grammar provided in `filename`.
"""
function run(filename, kwrdsfile)
    grammar = read(filename, String)
    omit = new_omit_array(grammar)
    
    omit_prelude!(grammar, omit)
    omit_token_declarations!(grammar, omit)
    omit_comments!(grammar, omit)
    omit_actions!(grammar, omit)
    omit_action_bindings!(grammar, omit)
    omit_semicolons!(grammar, omit)

    grammar = omit_marked(grammar, omit)
    grammar = add_stdlib(grammar)
    grammar = normalize_whitespace(grammar)

    println(grammar)

    kwrds = read_kwrds(kwrdsfile)
    convert2triple(grammar, kwrds)
   
    # remove instruction
    grammar = HerbGrammar.read_csg("output.txt")
    HerbGrammar.remove_rule!(grammar, 2)
    stdout_generation(grammar)
    #return grammar
end