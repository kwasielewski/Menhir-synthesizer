endrule(X):
    | X

anonymous(X):
    | X

midrule(X):
    | X

embedded(X):
    | X

option(X):
    |
    | X


ioption(X):
    |
    | X

boption(X):
    |
    | X

loption(X):
    |
    | X


pair(X, Y):
    | X Y


separated_pair(X, sep, Y):
    | X sep Y


preceded(opening, X):
    | opening X


terminated(X, closing):
    | X closing


delimited(opening, X, closing):
    | opening X closing


list(X):
    |  
    | X list(X)


nonempty_list(X):
    | X
    | X nonempty_list(X)


separated_list(separator, X):
    | loption(separated_nonempty_list(separator, X))


separated_nonempty_list(separator, X):
    | X
    | X separator separated_nonempty_list(separator, X)


rev(XS):
    | XS


flatten(XSS):
    | XSS


append(XS, YS):
    | XS YS
