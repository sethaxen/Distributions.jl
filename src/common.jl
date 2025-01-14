## sample space/domain

"""
`F <: VariateForm` specifies the form or shape of the variate or a sample.
"""
abstract type VariateForm end

"""
`F <: ArrayLikeVariate{N}` specifies the number of axes of a variate or
a sample with an array-like shape, e.g. univariate (scalar, `N == 0`),
multivariate (vector, `N == 1`) or matrix-variate (matrix, `N == 2`).
"""
abstract type ArrayLikeVariate{N} <: VariateForm end

const Univariate    = ArrayLikeVariate{0}
const Multivariate  = ArrayLikeVariate{1}
const Matrixvariate = ArrayLikeVariate{2}

"""
`F <: CholeskyVariate` specifies that the variate or a sample is of type
`LinearAlgebra.Cholesky`.
"""
abstract type CholeskyVariate <: VariateForm end

"""
`S <: ValueSupport` specifies the support of sample elements,
either discrete or continuous.
"""
abstract type ValueSupport end
struct Discrete   <: ValueSupport end
struct Continuous <: ValueSupport end

## Sampleable

"""
    Sampleable{F<:VariateForm,S<:ValueSupport}

`Sampleable` is any type able to produce random values.
Parametrized by a `VariateForm` defining the dimension of samples
and a `ValueSupport` defining the domain of possibly sampled values.
Any `Sampleable` implements the `Base.rand` method.
"""
abstract type Sampleable{F<:VariateForm,S<:ValueSupport} end

"""
    length(s::Sampleable)

The length of each sample. Always returns `1` when `s` is univariate.
"""
Base.length(s::Sampleable) = prod(size(s))
Base.length(::Sampleable{Univariate}) = 1
Base.length(s::Sampleable{Multivariate}) = throw(MethodError(length, (s,)))

"""
    size(s::Sampleable)

The size (i.e. shape) of each sample. Always returns `()` when `s` is univariate, and
`(length(s),)` when `s` is multivariate.
"""
Base.size(s::Sampleable)
Base.size(s::Sampleable{Univariate}) = ()
Base.size(s::Sampleable{Multivariate}) = (length(s),)

"""
    eltype(::Type{Sampleable})

The default element type of a sample. This is the type of elements of the samples generated
by the `rand` method. However, one can provide an array of different element types to
store the samples using `rand!`.
"""
Base.eltype(::Type{<:Sampleable{F,Discrete}}) where {F} = Int
Base.eltype(::Type{<:Sampleable{F,Continuous}}) where {F} = Float64

"""
    nsamples(s::Sampleable)

The number of values contained in one sample of `s`. Multiple samples are often organized
into an array, depending on the variate form.
"""
nsamples(t::Type{Sampleable}, x::Any)
nsamples(::Type{D}, x::Number) where {D<:Sampleable{Univariate}} = 1
nsamples(::Type{D}, x::AbstractArray) where {D<:Sampleable{Univariate}} = length(x)
nsamples(::Type{D}, x::AbstractVector) where {D<:Sampleable{Multivariate}} = 1
nsamples(::Type{D}, x::AbstractMatrix) where {D<:Sampleable{Multivariate}} = size(x, 2)
nsamples(::Type{D}, x::Number) where {D<:Sampleable{Matrixvariate}} = 1
nsamples(::Type{D}, x::Array{Matrix{T}}) where {D<:Sampleable{Matrixvariate},T<:Number} = length(x)

for func in (:(==), :isequal, :isapprox)
    @eval function Base.$func(s1::A, s2::B; kwargs...) where {A<:Sampleable, B<:Sampleable}
        nameof(A) === nameof(B) || return false
        fields = fieldnames(A)
        fields === fieldnames(B) || return false

        for f in fields
            isdefined(s1, f) && isdefined(s2, f) || return false
            $func(getfield(s1, f), getfield(s2, f); kwargs...) || return false
        end

        return true
    end
end

function Base.hash(s::S, h::UInt) where S <: Sampleable
    hashed = hash(Sampleable, h)
    hashed = hash(nameof(S), hashed)

    for f in fieldnames(S)
        hashed = hash(getfield(s, f), hashed)
    end

    return hashed
end

"""
    Distribution{F<:VariateForm,S<:ValueSupport} <: Sampleable{F,S}

`Distribution` is a `Sampleable` generating random values from a probability
distribution. Distributions define a Probability Distribution Function (PDF)
to implement with `pdf` and a Cumulated Distribution Function (CDF) to implement
with `cdf`.
"""
abstract type Distribution{F<:VariateForm,S<:ValueSupport} <: Sampleable{F,S} end

const UnivariateDistribution{S<:ValueSupport}   = Distribution{Univariate,S}
const MultivariateDistribution{S<:ValueSupport} = Distribution{Multivariate,S}
const MatrixDistribution{S<:ValueSupport}       = Distribution{Matrixvariate,S}
const NonMatrixDistribution = Union{UnivariateDistribution, MultivariateDistribution}

const DiscreteDistribution{F<:VariateForm}   = Distribution{F,Discrete}
const ContinuousDistribution{F<:VariateForm} = Distribution{F,Continuous}

const DiscreteUnivariateDistribution     = Distribution{Univariate,    Discrete}
const ContinuousUnivariateDistribution   = Distribution{Univariate,    Continuous}
const DiscreteMultivariateDistribution   = Distribution{Multivariate,  Discrete}
const ContinuousMultivariateDistribution = Distribution{Multivariate,  Continuous}
const DiscreteMatrixDistribution         = Distribution{Matrixvariate, Discrete}
const ContinuousMatrixDistribution       = Distribution{Matrixvariate, Continuous}

variate_form(::Type{<:Distribution{VF}}) where {VF} = VF

value_support(::Type{<:Distribution{VF,VS}}) where {VF,VS} = VS

# allow broadcasting over distribution objects
# to be decided: how to handle multivariate/matrixvariate distributions?
Broadcast.broadcastable(d::UnivariateDistribution) = Ref(d)

"""
    minimum(d::Distribution)

Return the minimum of the support of `d`.
"""
minimum(d::Distribution)

"""
    maximum(d::Distribution)

Return the maximum of the support of `d`.
"""
maximum(d::Distribution)

"""
    extrema(d::Distribution)

Return the minimum and maximum of the support of `d` as a 2-tuple.
"""
Base.extrema(d::Distribution) = minimum(d), maximum(d)

## TODO: the following types need to be improved
abstract type SufficientStats end
abstract type IncompleteDistribution end

const DistributionType{D<:Distribution} = Type{D}
const IncompleteFormulation = Union{DistributionType,IncompleteDistribution}

"""
    succprob(d::DiscreteUnivariateDistribution)

Get the probability of success.
"""
succprob(d::DiscreteUnivariateDistribution)

"""
    failprob(d::DiscreteUnivariateDistribution)

Get the probability of failure.
"""
failprob(d::DiscreteUnivariateDistribution)

# Temporary fix to handle RFunctions dependencies
"""
    @rand_rdist(::Distribution)

Mark a `Distribution` subtype as requiring RFunction calls. Since these calls
cannot accept an arbitrary random number generator as an input, this macro
creates new `rand(::Distribution, n::Int)` and
`rand!(::Distribution, X::AbstractArray)` functions that call the relevant
RFunction. Calls using another random number generator still work, but rely on
a quantile function to operate.
"""
macro rand_rdist(D)
    esc(quote
        function rand(d::$D, n::Int)
            [rand(d) for i in Base.OneTo(n)]
        end
        function rand!(d::$D, X::AbstractArray)
            for i in eachindex(X)
                X[i] = rand(d)
            end
            return X
        end
    end)
end
