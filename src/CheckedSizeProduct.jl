module CheckedSizeProduct
    export checked_size_product

    """
        checked_size_product(::Tuple{Any, Vararg})

    In short; a safe product, suitable for computing, e.g., the value of
    `length(dense_array)` from the value of `size(dense_array)`. In case everything
    is as expected, return the value of the product of the elements of the given
    tuple. Otherwise, return a `NamedTuple` containing Boolean values with
    information on the encountered problems.

    In more detail; given a nonempty tuple of `Integer`-likes:
    1. Promote the elements to a common concrete type, say `T`. The user must
       ensure `T` supports `Base.Checked.mul_with_overflow`, `iszero`, `typemax`,
       `<` and `==`.
    2. Calculate the product. In case no element is negative, no element is
       `typemax(T)` and the product is representable as `T`, return the product.
       Otherwise, return a `NamedTuple` containing two Boolean properties:
        * `any_is_negative`: at least one element is negative
        * `any_is_typemax`: at least one element is the maximum value representable
          in the given type, as given by `typemax`
       If a `NamedTuple` is returned with both fields `false`, the product is not
       representable as `T`.

    Throws when given an empty tuple to avoid having to choose a default return
    type arbitrarily.
    """
    function checked_size_product end

    const NonemptyNTuple = Tuple{T, Vararg{T, N}} where {T, N}

    macro assume_terminates_locally(x)
        if isdefined(Base, Symbol("@assume_effects"))
            :(Base.@assume_effects :terminates_locally $x)
        else
            x
        end
    end

    @assume_terminates_locally function checked_dims_impl(t::NonemptyNTuple)
        a = first(t)
        have_overflow = false
        for i ∈ eachindex(t)[2:end]
            b = t[i]
            (m, o) = Base.Checked.mul_with_overflow(a, b)
            a = m
            have_overflow |= o
        end
        (a, have_overflow)
    end

    @assume_terminates_locally function any_impl(f, t::NonemptyNTuple)
        a = f(first(t))::Bool  # assuming no `missing`
        for i ∈ eachindex(t)[2:end]
            b = f(t[i])::Bool
            a |= b
        end
        a
    end

    # define singleton types for these functions to be able to dispatch on them
    function is_negative(x)
        x < 0
    end
    function is_typemax(x)
        x == typemax(x)
    end

    const HasGoodEffects = Union{
        Int8, Int16, Int32, Int64, Int128,
    }

    function checked_dims(t::NonemptyNTuple)
        checked_dims_impl(t)
    end
    function any_(f, t::NonemptyNTuple)
        any_impl(f, t)
    end
    @static if isdefined(Base, Symbol("@assume_effects"))
        Base.@assume_effects :nothrow function checked_dims(
            t::(NonemptyNTuple{T} where {T <: HasGoodEffects}),
        )
            checked_dims_impl(t)
        end
        Base.@assume_effects :nothrow function any_(
            f::Union{typeof(iszero), typeof(is_negative), typeof(is_typemax)},
            t::(NonemptyNTuple{T} where {T <: HasGoodEffects}),
        )
            any_impl(f, t)
        end
    end

    function checked_size_product_impl(t::NonemptyNTuple{T, N}) where {T, N}
        any_is_zero = any_(iszero, t)
        any_is_negative = any_(is_negative, t)
        any_is_typemax = any_(is_typemax, t)
        (product, have_overflow) = checked_dims(t)
        is_not_representable = have_overflow & !any_is_zero
        if !(any_is_negative | any_is_typemax | is_not_representable)
            product
        else
            (; any_is_negative = any_is_negative, any_is_typemax = any_is_typemax)
        end
    end

    function checked_size_product(t::NonemptyNTuple{Any})
        p = promote(t...)
        checked_size_product_impl(p)  # avoid infinite recursion in case `promote` is quirky
    end
    function checked_size_product(t::NonemptyNTuple)
        checked_size_product_impl(t)
    end
end
