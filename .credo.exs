%{
  configs: [
    %{
      name: "default",
      strict: true,
      # These are not in the default list
      checks: [
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
        {Credo.Check.Consistency.UnusedVariableNames, []},
        {Credo.Check.Readability.BlockPipe, []},
        {Credo.Check.Readability.ImplTrue, []},
        {Credo.Check.Readability.MultiAlias, []},
        {Credo.Check.Readability.NestedFunctionCalls, []},
        {Credo.Check.Readability.OneArityFunctionInPipe, []},
        {Credo.Check.Readability.OnePipePerLine, []},
        {Credo.Check.Readability.SeparateAliasRequire, []},
        {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
        {Credo.Check.Readability.SinglePipe, []},
        {Credo.Check.Readability.Specs, []},
        {Credo.Check.Readability.StrictModuleLayout, []},
        # Throwing an exception because we're using `with` as a variable name
        # {Credo.Check.Readability.WithCustomTaggedTuple, []},
        {Credo.Check.Refactor.ABCSize, []},
        {Credo.Check.Refactor.AppendSingleItem, []},
        {Credo.Check.Refactor.Apply, []},
        {Credo.Check.Refactor.CaseTrivialMatches, []},
        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.FilterReject, []},
        {Credo.Check.Refactor.IoPuts, []},
        {Credo.Check.Refactor.MapMap, []},
        {Credo.Check.Refactor.ModuleDependencies, []},
        {Credo.Check.Refactor.NegatedIsNil, []},
        {Credo.Check.Refactor.PassAsyncInTestCases, []},
        {Credo.Check.Refactor.PerceivedComplexity, []},
        {Credo.Check.Refactor.PipeChainStart, []},
        {Credo.Check.Refactor.RejectFilter, []},
        {Credo.Check.Refactor.RejectReject, []},
        {Credo.Check.Refactor.VariableRebinding, []},
        {Credo.Check.Warning.ForbiddenModule, []},
        {Credo.Check.Warning.LeakyEnvironment, []},
        {Credo.Check.Warning.MapGetUnsafePass, []},
        {Credo.Check.Warning.MixEnv, []},
        {Credo.Check.Warning.UnsafeToAtom, []}
      ]
    }
  ]
}
