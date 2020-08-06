# ColoredLLCodes
[![Build Status][action-img]][action-url]
[![Build Status][pkgeval-img]][pkgeval-url]
[![coverage][codecov-img]][codecov-url]

Color `code_llvm` and `code_native` printing

## Screenshots
![code_llvm in Windows Terminal](images/terminal_llvm.png)

![code_native in Jupyter](images/jupyter_native.png)


## Installation
```julia
julia> import Pkg; Pkg.add("ColoredLLCodes")
```
or
```julia
pkg> add ColoredLLCodes
```

## Customizing colorscheme
You can customize the printing styles by overwriting the dictionary
`ColoredLLCodes.llstyle`. Each style is specified by a tuple of the bold flag
and the color keyword or ANSI color code (0-255).
For example:
```julia
# Monokai256
ColoredLLCodes.llstyle[:default]     = (false, :normal)
ColoredLLCodes.llstyle[:comment]     = (false, 101)
ColoredLLCodes.llstyle[:label]       = (false, :normal)
ColoredLLCodes.llstyle[:instruction] = ( true, 197)
ColoredLLCodes.llstyle[:type]        = (false, 81)
ColoredLLCodes.llstyle[:number]      = (false, 141)
ColoredLLCodes.llstyle[:bracket]     = (false, :normal)
ColoredLLCodes.llstyle[:variable]    = (false, 208)
ColoredLLCodes.llstyle[:keyword]     = (false, 197)
ColoredLLCodes.llstyle[:funcname]    = (false, 208)
```

[action-img]: https://github.com/kimikage/ColoredLLCodes.jl/workflows/CI/badge.svg
[action-url]: https://github.com/kimikage/ColoredLLCodes.jl/actions

[pkgeval-img]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/C/ColoredLLCodes.svg
[pkgeval-url]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html

[codecov-img]: https://codecov.io/gh/kimikage/ColoredLLCodes.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/kimikage/ColoredLLCodes.jl
