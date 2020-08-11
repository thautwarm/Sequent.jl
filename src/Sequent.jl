module Sequent
using MLStyle
export @sequent, @semantics
@nospecialize
@data Judgement begin
    Assertion(
        line::LineNumberNode,
        rule_name::Symbol,
        vectorized::Bool,
        judge_op::Symbol,
        context,
        pattern,
        ret)
    
    EqMatch(line::LineNumberNode, pattern, value)
end

struct SequentDef
    conditions :: Vector{Judgement}
    case :: Assertion
end

macro sequent(name, formula)
    name isa Symbol || error("formula name must be a symbol!")
    @match formula Expr(:block, stmts...) =>
    begin
        conditions = Judgement[]
        line = __source__
        for stmt in stmts
            @switch stmt begin
            @case line::LineNumberNode
                continue
            @case :($a = $b)
                push!(conditions, EqMatch(line, a, b))
                continue
            @case Expr(:call,
                    :(=>) && let is_vec = false end ||
                    :(.=>) && let is_vec = true end,
                    Expr(:call, judge_op::Symbol, context, pattern),
                    result) &&
                    if startswith(string(judge_op), "⊢") end
                push!(conditions,
                      Assertion(
                        line, name, is_vec,
                        judge_op, context, pattern, result))
                continue
            end
        end
        length(conditions) >= 1 && conditions[end] isa Assertion ||
        error("malformed sequent definition $name at $__source__")

        case = pop!(conditions)
        SequentDef(conditions, case)
    end
end

function semantics(seqs::Vector{SequentDef}, __source__::LineNumberNode)
    groups = Dict{Symbol, Vector{SequentDef}}()
    for seq in seqs
        group = get!(groups, seq.case.judge_op) do
            SequentDef[]
        end
        push!(group, seq)
    end
    ctx_sym = gensym("ctx")
    term_sym = gensym("term")
    code = Expr(:block)
    for (funcname, group) in groups
        when_cases = Tuple{Expr, Any}[]
        for seq in group
            case_clauses = Expr(:block)
            main_case = Expr(:tuple, seq.case.context, seq.case.pattern)
            push!(
                case_clauses.args,
                :($main_case = ($ctx_sym, $term_sym)))
            for cond in seq.conditions
                @match cond begin
                    EqMatch(line, pattern, value) =>
                        begin
                            value = Expr(:block, line, value)
                            push!(case_clauses.args, :($pattern = $value))
                        end
                    Assertion(
                        line, name, is_vec,
                        judge_op, context, pattern, result) =>
                        begin
                            context === :_ && (context = :nothing)
                            fcall = is_vec ?
                                :(($term_sym -> $judge_op($context, $term_sym)).($pattern)) :
                                :($judge_op($context, $pattern))
                            fcall = Expr(:block, line, fcall)
                            push!(case_clauses.args, :($result = $fcall))
                        end
                end
            end
            push!(
                when_cases,
                (case_clauses, seq.case.ret)
            )
        end
        hd, tl = when_cases[1], @view when_cases[2:end]
        when_block = Expr(:block)
        push!(when_block.args, hd[2])
        for (binding, result) in tl
            push!(when_block.args, :(@when $binding))
            push!(when_block.args, result)
        end
        push!(when_block.args, :(@otherwise))
        push!(when_block.args, :($error("unrecognised input" * $string($term_sym))))
        match_expression =
            Expr(:let, 
                hd[1],
                when_block)
        
        push!(
            code.args,
            Expr(
                :function,
                Expr(:call, funcname, ctx_sym, term_sym),
                Expr(:block,
                    Expr(
                        :macrocall,
                        GlobalRef(MLStyle, Symbol("@when")),
                        __source__,
                        match_expression))))
    end
    code
end

macro semantics(seqs)
    esc(semantics(__module__.eval(seqs), __source__))
end
@specialize
end
