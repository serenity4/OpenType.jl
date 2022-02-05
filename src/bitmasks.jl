abstract type BitMask{T<:Unsigned} end

Base.read(io::IO, T::Type{<:BitMask{_T}}) where {_T} = T(read(io, _T))
Base.broadcastable(x::BitMask) = Ref(x)

function generate_bitmask_flags(type, decl)
    identifier, value = decl.args
    :(const $identifier = $type($value))
end

"""
    @bitmask_flag BitFlags::UInt32 begin
        FLAG_A = 1
        FLAG_B = 2
        FLAG_C = 4
    end

Enumeration of bitmask flags that can be combined with `&`, `|` and `xor`, forbidding the combination of flags from different bitmasks.
"""
macro bitmask_flag(typedecl, expr)
    if Base.is_expr(typedecl, :(::), 2)
        type, eltype = typedecl.args
    else
        error("First argument to @bitmask_flag must be of the form 'type::eltype'")
    end
    decls = filter(x -> typeof(x) ≠ LineNumberNode, expr.args)

    exs = [
        :(
            Base.@__doc__ struct $type <: BitMask{$eltype}
                val::$eltype
            end
        );
        generate_bitmask_flags.(type, decls)
    ]

    Expr(:block, esc.(exs)...)
end

Base.:(&)(a::BitMask, b::BitMask) = error("Bitwise operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")
Base.:(|)(a::BitMask, b::BitMask) = error("Bitwise operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")
Base.xor(a::BitMask, b::BitMask) = error("Bitwise operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")
Base.isless(a::BitMask, b::BitMask) = error("Bitwise operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")
Base.:(==)(a::BitMask, b::BitMask) = error("Operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")
Base.in(a::BitMask, b::BitMask) = error("Operation not allowed between incompatible bitmasks '$(typeof(a))', '$(typeof(b))'")

Base.:(&)(a::T, b::T) where {T <: BitMask} = T(a.val & b.val)
Base.:(|)(a::T, b::T) where {T <: BitMask} = T(a.val | b.val)
Base.xor(a::T, b::T) where {T <: BitMask} = T(xor(a.val, b.val))
Base.isless(a::T, b::T) where {T <: BitMask} = isless(a.val, b.val)
Base.:(==)(a::T, b::T) where {T <: BitMask} = a.val == b.val
Base.in(a::T, b::T) where {T <: BitMask} = a & b == a

Base.:(&)(a::T, b::Integer) where {T <: BitMask} = T(a.val & b)
Base.:(|)(a::T, b::Integer) where {T <: BitMask} = T(a.val | b)
Base.xor(a::T, b::Integer) where {T <: BitMask} = T(xor(a.val, b))
Base.isless(a::T, b::Integer) where {T <: BitMask} = isless(a.val, b)
Base.in(a::T, b::Integer) where {T <: BitMask} = a & b == a

Base.:(&)(a::Integer, b::T) where {T <: BitMask} = b & a
Base.:(|)(a::Integer, b::T) where {T <: BitMask} = b | a
Base.xor(a::Integer, b::T) where {T <: BitMask} = xor(b, a)
Base.isless(a::Integer, b::T) where {T <: BitMask} = isless(a, b.val) # need b.val to prevent stackoverflow
Base.in(a::Integer, b::T) where {T <: BitMask} = a | b == b

(::Type{T})(bm::BitMask) where {T <: Integer} = T(bm.val)

Base.convert(T::Type{<:Integer}, bm::BitMask) = T(bm.val)
Base.convert(T::Type{<:BitMask}, val::Integer) = T(val)

Base.typemax(T::Type{<:BitMask{_T}}) where {_T} = T(typemax(_T))
