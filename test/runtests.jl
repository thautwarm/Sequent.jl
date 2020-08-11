using Sequent
using MLStyle
using HMRowUnification
using Test


@data Nat begin
    Z
    S(Nat)
end

rule_z = @sequent FOLD_Z begin
    _ ⊢ₛ Z => 0
end

rule_s = @sequent FOLD_S begin
    _ ⊢ₛ term => n
    _ ⊢ₛ S(term) => n + 1 
end

@semantics [rule_z, rule_s]

@testset "Nat" begin


@test (nothing ⊢ₛ Z) == 0
@test (nothing ⊢ₛ S(S(Z))) == 2

end

@data ML begin
    LApp(ML, ML)
    LFun(Symbol, ML)
    LVar(Symbol)
    LVal(Int)
end


ImD = Base.ImmutableDict

struct Sigma{O}
    unbox :: ImD{Symbol, O}
end

Sigma{O}() where O = Sigma(ImD{Symbol, O}())

Base.getindex(s::Sigma{O}, x::Pair{Symbol, A}) where {O, A<:O} =
    Sigma(ImD(s.unbox, x))
Base.getindex(s::Sigma{O}, x::Symbol) where O = 
    s.unbox[x]

(s::Sigma{O})(x::Pair{Symbol, A}) where {O, A<:O} = ImD(s, x)

r_app = @sequent APP begin
    (Γ, σ) ⊢ʷ a => ta
    (Γ, σ) ⊢ʷ f => Arrow(ta′, tr)
    true = Γ.unify(ta, ta′)
    (Γ, σ) ⊢ʷ LApp(f, a) => tr
end

r_var = @sequent VAR begin
    (Γ, σ) ⊢ʷ LVar(s) => σ[s]
end

r_fun = @sequent FUN begin
    a′ = Γ.new_tvar()
    (Γ, σ[a => a′]) ⊢ʷ r => tr
    (Γ, σ) ⊢ʷ LFun(a, r) => Arrow(a′, tr)
end

r_val = @sequent VAL begin
    _ ⊢ʷ LVal(_) => Nom(:int)
end

@semantics [r_app, r_fun, r_val, r_var]

@testset "ML" begin
    tctx = HMT[]
    Γ = mk_tcstate(tctx)
    σ = Sigma{HMT}()
    int_t = Nom(:int)
    σ = σ[:add => Arrow(int_t, Arrow(int_t, int_t))]
    term = 
        LFun(:a,
            LApp(
                LApp(
                    LVar(:add),
                    LVar(:a)),
                LVar(:a)))
    infer_ty =  (Γ, σ) ⊢ʷ term
    @test Γ.prune(infer_ty) == Arrow(int_t, int_t)
end