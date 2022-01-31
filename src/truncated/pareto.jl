truncated(d0::Pareto, l::Real, ::Nothing) = Pareto(d0.α, max(d0.θ, l))

function mean(d::Truncated{<:Pareto,Continuous})
    d0 = d.untruncated
    l = max(d.lower, d0.θ)
    u = d.upper
    α = d0.α
    if isone(α)
        return (l * xlogx(u) - u * xlogx(l)) / (u - l)
    else

    end
end
