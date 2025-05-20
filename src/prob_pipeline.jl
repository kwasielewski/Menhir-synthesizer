"""
	run_ppb()

Run the code synthesis pipeline based on probabilistic grammar provided in `probabilistic.txt`.
"""
function run_ppb()

	grammar = HerbGrammar.read_pcsg("probabilistic.txt")
	# remove labeled statement variant
	#HerbGrammar.add_rule!(grammar, :(FILE = ((RAW_MANY3FUNCTION_DEFINITION4, FUNCTION_DEFINITION), 
  #                      ("function", "main", "(", (""), ")", "{", (RAW_MANY3SIMPLE_STRUCT_STATEMENT4, ("return", ";")), "}"))))
	#stdout_generation(grammar)
	directory_generation(grammar; ppb=true)
	#return grammar
end
