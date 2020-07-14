module ColoredLLCodes

import InteractiveUtils: _dump_function, code_llvm, code_native

const IO_ = Union{Base.AbstractPipe, Base.LibuvStream} # avoid overwriting

llstyle = Dict{Symbol, Tuple{Bool, Union{Symbol, Int}}}(
    :default     => (false, :light_black),
    :comment     => (false, :green),
    :label       => (false, :light_red),
    :instruction => ( true, :light_cyan),
    :type        => (false, :cyan),
    :number      => (false, :yellow),
    :bracket     => (false, :yellow),
    :variable    => (false, :normal),
    :keyword     => (false, :light_magenta),
    :funcname    => (false, :light_yellow),
)

const num_regex = r"^(?:\$?-?\d+|0x[0-9A-Fa-f]+|-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)$"

function printstyled_ll(io::IO, x, s::Symbol, trailing_spaces="")
    isempty(x) || printstyled(io, x, bold=llstyle[s][1], color=llstyle[s][2])
    print(io, trailing_spaces)
end

function code_llvm(io::IO_, @nospecialize(f), @nospecialize(types),
                   raw::Bool, dump_module::Bool=false, optimize::Bool=true,
                   debuginfo::Symbol=:default)
    if VERSION >= v"1.1"
        d = _dump_function(f, types, false, false, !raw, dump_module, :att, optimize,
                           debuginfo)
    else
        d = _dump_function(f, types, false, false, !raw, dump_module, :att, optimize)
    end
    if get(io, :color, false)
        print_llvm(io, d)
    else
        print(io, d)
    end
end

function print_llvm(io::IO, code::String)
    buf = IOBuffer(code)
    for line in eachline(buf)
        m = match(r"^(\s*)((?:[^;]|;\")*)(.*)$", line)
        m === nothing && continue
        indent, tokens, comment = m.captures
        print(io, indent)
        print_llvm_tokens(io, tokens)
        printstyled_ll(io, comment, :comment)
        println(io)
    end
end

const llvm_types =
    r"^(?:void|half|float|double|x86_\w+|ppc_\w+|label|metadata|type|opaque|token|i\d+)$"
const llvm_cond = r"^(?:[ou]?eq|[ou]?ne|[uso][gl][te]|ord|uno|true|false)$"

function print_llvm_tokens(io, line)
    tokens = line
    m = match(r"^((?:[^\s:]+:)?)(\s*)(.*)", tokens)
    if m !== nothing
        label, spaces, tokens = m.captures
        printstyled_ll(io, label, :label, spaces)
    end
    m = match(r"^(%[^\s=]+)(\s*)=(\s*)(.*)", tokens)
    if m !== nothing
        result, spaces, spaces2, tokens = m.captures
        printstyled_ll(io, result, :variable, spaces)
        printstyled_ll(io, '=', :default, spaces2)
    end
    m = match(r"^([a-z]\w*)(\s*)(.*)", tokens)
    if m !== nothing
        inst, spaces, tokens = m.captures
        printstyled_ll(io, inst, inst == "define" ? :keyword : :instruction, spaces)
    end

    print_llvm_operands(io, tokens)
end

function print_llvm_operands(io, tokens)
    while !isempty(tokens)
        tokens = print_llvm_operand(io, tokens)
    end
    return tokens
end

function print_llvm_operand(io, tokens)
    islabel = false
    while !isempty(tokens)
        m = match(r"^,(\s*)(.*)", tokens)
        if m !== nothing
            spaces, tokens = m.captures
            printstyled_ll(io, ',', :default, spaces)
            break
        end
        m = match(r"^(\*+)(\s*)(.*)", tokens)
        if m !== nothing
            asterisks, spaces, tokens = m.captures
            printstyled_ll(io, asterisks, :default, spaces)
            continue
        end
        m = match(r"^([({\[<])(\s*)(.*)", tokens)
        if m !== nothing
            bracket, spaces, tokens = m.captures
            printstyled_ll(io, bracket, :bracket, spaces)
            tokens = print_llvm_operands(io, tokens) # enter
            continue
        end
        m = match(r"^([)}\]>])(\s*)(.*)", tokens)
        if m !== nothing
            bracket, spaces, tokens = m.captures
            printstyled_ll(io, bracket, :bracket, spaces)
            break # leave
        end

        m = match(r"^([^\s,*(){}\[\]<>]+)(\s*)(.*)", tokens)
        m === nothing && break
        token, spaces, tokens = m.captures
        if occursin(llvm_types, token)
            printstyled_ll(io, token, :type)
            islabel = token == "label"
        elseif occursin(llvm_cond, token) # condition code is instruction-level
            printstyled_ll(io, token, :instruction)
        elseif occursin(num_regex, token)
            printstyled_ll(io, token, :number)
        elseif occursin(r"^@.+$", token)
            printstyled_ll(io, token, :funcname)
        elseif occursin(r"^%.+$", token)
            printstyled_ll(io, token, islabel ? :label : :variable)
            islabel = false
        elseif occursin(r"^[a-z]\w+$", token)
            printstyled_ll(io, token, :keyword)
        else
            printstyled_ll(io, token, :default)
        end
        print(io, spaces)
    end
    return tokens
end

# code_native
# ===========

function code_native(io::IO_, @nospecialize(f), @nospecialize(types=Tuple);
                     syntax::Symbol=:att, debuginfo::Symbol=:default)
    if VERSION >= v"1.1"
        d = _dump_function(f, types, true, false, false, false, syntax, true, debuginfo)
    else
        d = _dump_function(f, types, true, false, false, false, syntax, true)
    end
    if get(io, :color, false)
        print_native(io, d)
    else
        print(io, d)
    end
end

function print_native(io::IO, code::String, arch::Symbol=sys_arch_category())
    archv = Val(arch)
    buf = IOBuffer(code)
    for line in eachline(buf)
        m = match(r"^(\s*)((?:[^;#/]|#\S|;\"|/[^/])*)(.*)$", line)
        m === nothing && continue
        indent, tokens, comment = m.captures
        print(io, indent)
        print_native_tokens(io, tokens, archv)
        printstyled_ll(io, comment, :comment)
        println(io)
    end
end

function sys_arch_category()
    if Sys.ARCH === :x86_64 || Sys.ARCH === :i686
        :x86
    elseif Sys.ARCH === :aarch64 || startswith(string(Sys.ARCH), "arm")
        :arm
    else
        :unsupported
    end
end

print_native_tokens(io, line, ::Val) = print(io, line)

function print_native_tokens(io, line, ::Val{:x86})
    tokens = line
    m = match(r"^((?:[^\s:]+:)?)(\s*)(.*)", tokens)
    if m !== nothing
        label, spaces, tokens = m.captures
        printstyled_ll(io, label, :label, spaces)
    end
    m = match(r"^([a-z]\w*)(\s*)(.*)", tokens)
    if m !== nothing
        instruction, spaces, tokens = m.captures
        printstyled_ll(io, instruction, :instruction, spaces)
    end

    isfuncname = false
    while !isempty(tokens)
        m = match(r"^([,:*])(\s*)(.*)", tokens)
        if m !== nothing
            sym, spaces, tokens = m.captures
            printstyled_ll(io, sym, :default, spaces)
            isfuncname = false
            continue
        end
        m = match(r"^([(){}\[\]])(\s*)(.*)", tokens)
        if m !== nothing
            bracket, spaces, tokens = m.captures
            printstyled_ll(io, bracket, :bracket, spaces)
            continue
        end

        m = match(r"^([^\s,:*(){}\[\]]+)(\s*)(.*)", tokens)
        m === nothing && break
        token, spaces, tokens = m.captures
        if occursin(num_regex, token)
            printstyled_ll(io, token, :number)
        elseif occursin(r"(?:[dq]?word|byte|ptr|offset)", token)
            printstyled_ll(io, token, :keyword)
            isfuncname = token == "offset"
        elseif occursin(r"^L.+$", token)
            printstyled_ll(io, token, :label)
        elseif occursin(r"^\$.+$", token)
            printstyled_ll(io, token, :funcname)
        elseif occursin(r"^%?(?:[a-z]\w+|\"[^\"]+\")$", token)
            printstyled_ll(io, token, isfuncname ? :funcname : :variable)
            isfuncname = false
        else
            printstyled_ll(io, token, :default)
        end
        print(io, spaces)
    end
end

const arm_cond = r"^(?:eq|ne|cs|ho|cc|lo|mi|pl|vs|vc|hi|ls|[lg][te]|al|nv)$"
function print_native_tokens(io, line, ::Val{:arm})
    tokens = line
    m = match(r"^((?:[^\s:]+:|\"[^\"]+\":)?)(\s*)(.*)", tokens)
    if m !== nothing
        label, spaces, tokens = m.captures
        printstyled_ll(io, label, :label, spaces)
    end
    haslabel = false
    m = match(r"^([a-z][\w.]*)(\s*)(.*)", tokens)
    if m !== nothing
        instruction, spaces, tokens = m.captures
        printstyled_ll(io, instruction, :instruction, spaces)
        haslabel = occursin(r"^(?:bl?|bl?\.\w\w|[ct]bn?z)?$", instruction)
    end

    while !isempty(tokens)
        m = match(r"^([,])(\s*)(.*)", tokens)
        if m !== nothing
            sym, spaces, tokens = m.captures
            printstyled_ll(io, sym, :default, spaces)
            continue
        end
        m = match(r"^([(){}\[\]])(\s*)(.*)", tokens)
        if m !== nothing
            bracket, spaces, tokens = m.captures
            printstyled_ll(io, bracket, :bracket, spaces)
            continue
        end
        m = match(r"^#([0-9a-fx.-]+)(\s*)(.*)", tokens)
        if m !== nothing && occursin(num_regex, m.captures[1])
            num, spaces, tokens = m.captures
            printstyled_ll(io, "#" * num, :number, spaces)
            continue
        end

        m = match(r"^([^\s,(){}\[\]]+)(\s*)(.*)", tokens)
        m === nothing && break
        token, spaces, tokens = m.captures
        if occursin(r"^(?:lsl|lsr|asr|!)$", token)
            printstyled_ll(io, token, :keyword)
        elseif occursin(arm_cond, token)
            printstyled_ll(io, token, :keyword)
        elseif occursin(r"^(?:[\w.]+|\"[^\"]+\")$", token)
            islabel = haslabel & !occursin(',', tokens)
            printstyled_ll(io, token, islabel ? :label : :variable)
        else
            printstyled_ll(io, token, :default)
        end
        print(io, spaces)
    end
end

end # module
