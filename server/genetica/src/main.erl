-module(main).
-export([start/2]).
-import(conversions, [bitstr_to_list/1, list_to_bitstr/1]).
-import(genetica_utils, [atom_to_integer/1, atom_to_float/1, atom_append/2]).
-import(selection_mechanisms, [roulette_selection_fn/2, sigma_scale/2,
                               boltzmann_scale/2, rank_scale/2]).

start(Sock, [Generations, Popcount, ASel_method, K, P,
             AEval_method, AProtocol, M, Module | T]) ->
    %% Make run truly random
    random:seed(now()),
    %% Argument parsing from here on
    [Sel_metfn, Eval_method, Protocol] =
        [atom_append(X, Y) ||
            {X, Y} <- lists:zip([ASel_method, AEval_method, AProtocol],
                                ["_selection_fn", "_scale", "_fn"])],
    {rand, R, p_to_g, PG, g_to_p, GP,
     fitness, F, cross, C, mut, Mut} = fetch_fns(Module, T),
    %% Parsing done
    Fitness = add_fitness_fn(F, fun selection:Eval_method/2),
    Sel_method = selection:Sel_metfn([K, P]),
    Make_child = make_child_fn(Sel_method, C, Mut, PG, GP),
    Devel_and_select = selection:Protocol(Make_child, Sel_method, 
                                          Fitness, [Popcount, M]),
    Initpop = generate_random_pop(Popcount, R, GP),
    Analyzefn = Module:analyze_fn(Sock, only_fitness_fn(F)),
    Analyzefn(Initpop),
    Init_T = Generations/2,
    Cooldown = math:pow(7, 4/(3*Generations)) *
               math:pow(1/Generations, 4/(3*Generations)),
    genetica_loop(Generations - 1, Initpop, [Generations, Init_T, Cooldown],
                  Analyzefn, Devel_and_select),
    ok = gen_tcp:close(Sock).

generate_random_pop(Popcount, Rand_gtype, GtoP) ->
    [GtoP(Genome) || Genome <- genetica_utils:repeatedly(Popcount, Rand_gtype)].

genetica_loop(0, _Pop, _Tvals, _Analyzefn, _Develop_and_select) ->
    done;
genetica_loop(Iters, Pop, [Gens, T, Cooldown], Analyzefn, Develop_and_select) ->
    Newpop = Develop_and_select(Pop, [T]),
    Analyzefn(Newpop),
    NT = new_temp(Iters, Gens, T, Cooldown),
    genetica_loop(Iters - 1, Newpop, [Gens, NT, Cooldown],
                  Analyzefn, Develop_and_select).

new_temp(Iters, Gens, T, _Cooldown)
  when Iters =< Gens/4 ->
    T;
new_temp(_Iters, _Gens, T, Cooldown) ->
    T * Cooldown.

add_fitness_fn(F, Scale) ->
    fun (Pop, Scale_args) ->
            Unscaled = [{indiv, I, fitness, F(I, Pop)} || I <- Pop],
            Scale(Unscaled, Scale_args)
    end.

only_fitness_fn(F) ->
    fun (Pop) ->
            [F(I, Pop) || I <- Pop]
    end.

make_child_fn(Sel_method, Crossfn, Mutfn, PG, GP) ->
    Parentfn = pick_parents_fn(Sel_method),
    Cproduce = child_producer_fn(Crossfn, Mutfn),
    fun (FPop) ->
            [PG1, PG2] = [PG(X) || X <- Parentfn(FPop)],
            CG = Cproduce(PG1, PG2),
            GP(CG)
    end.

pick_parents_fn(Sel_method) ->
    fun (FPop) ->
            FP1 = Sel_method(FPop),
            {indiv, P1, fitness, _} = FP1,
            {indiv, P2, fitness, _} = Sel_method(FPop -- [FP1]),
            [P1, P2]
    end.

child_producer_fn(Crossfn, Mutfn) ->
    fun (PG1, PG2) ->
            Mutfn(Crossfn(PG1, PG2))
    end.

fetch_fns(Module, Opts) ->
    Rand_gtype = Module:random_genotype_fn(Opts),
    PtoG = Module:phenotype_to_genotype_fn(Opts),
    GtoP = Module:genotype_to_phenotype_fn(Opts),
    Fitness = Module:fitness_fn(Opts),
    Crossfn = Module:crossover_fn(Opts),
    Mutfn = Module:mutation_fn(Opts),
    {rand, Rand_gtype, p_to_g, PtoG, g_to_p, GtoP,
     fitness, Fitness, cross, Crossfn, mut, Mutfn}.

%% (1) choose a genetic representation
%% (2) build a population
%% (3) design a fitness function
%% (4) choose a selection operator
%% (5) choose a recombination operator
%% (6) choose a mutation operator
%% (7) devise a data analysis procedure.
