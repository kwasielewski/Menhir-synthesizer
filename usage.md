1. Install Julia using [juliaup](https://github.com/JuliaLang/juliaup) or another method from [Julia's repository](https://github.com/JuliaLang/julia)
2. Clone this repository
```
git clone https://github.com/kwasielewski/Menhir-synthesizer.git
```
3. Create output directory
```
mkdir results
```
4. Run
```
julia --project=<path to Menhir-synthesizer>
```
In REPL now run
```
julia> using MenhirSynth
```
and to finally run the generation process
```
julia> MenhirSynth.run("path to grammar .mly file", "path to keywords file")
```

Keywords file is there to omit parsing of lexer .mll file. Instead all direct token-string pairs are stored in that file.