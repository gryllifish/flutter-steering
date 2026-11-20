# State management

Use what the project uses. Read only the section for the detected library.

## Riverpod (2.x/3.x)
- Codegen projects (`riverpod_annotation`): only `@riverpod` functions and
  classes; no hand-written `Provider(...)`. Regenerate after changes.
- `ref.watch` in `build` (widgets and providers), `ref.read` in callbacks,
  `ref.listen` for side effects (navigation, snackbars).
- `AsyncNotifier` for async state; render with an exhaustive `switch` on
  `AsyncValue` (`AsyncData`, `AsyncError`, `AsyncLoading`) or `.when`.
- Mutations: set `state = const AsyncLoading()` only when the UI needs it,
  use `AsyncValue.guard`, and avoid losing previous data
  (`copyWithPrevious` / keep data while refreshing).
- Keep providers small and composable; derive with `select` to limit
  rebuilds. Family args must have value equality.
- Auto-dispose is the default; `keepAlive` only with a reason.
- Never store `BuildContext` or widgets in providers. Never use `ref` after
  `await` without checking `ref.mounted` (Riverpod 3).
- Tests: `ProviderContainer.test()` (or a container with `addTearDown(dispose)`)
  and `overrides` for repositories.

## Bloc / Cubit
- Cubit for simple state, Bloc when events need transformation (debounce,
  droppable, restartable via `bloc_concurrency`).
- State: one sealed class hierarchy or one immutable class with a status
  enum; be consistent with the project. Events are past-tense or imperative
  nouns, consistently.
- No `BuildContext` in blocs; no blocs calling other blocs directly (share
  repositories or use streams at the repository level).
- `BlocBuilder` with `buildWhen`, `BlocSelector` for slices, `BlocListener`
  for side effects. Provide blocs as low in the tree as possible.
- Always `emit` new instances; never mutate state. Guard `emit` after await
  with `isClosed` if the bloc can close mid-operation.
- Tests: `bloc_test` (`build`, `act`, `expect`, `verify`) with mocked
  repositories.

## Provider / ChangeNotifier
- `ChangeNotifier` holds state and exposes methods; `notifyListeners` once
  per logical change. `context.watch` in build, `context.read` in callbacks,
  `Selector`/`context.select` to limit rebuilds.
- Dispose notifiers owned by `ChangeNotifierProvider(create:)`; use
  `.value` only for existing instances.

## GetX, MobX, others
- Follow the project's conventions strictly; do not migrate opportunistically.
- Keep the same layering rules: the state holder has no widget code, widgets
  have no business logic.
- If asked about migration, propose an incremental plan (feature by feature,
  both systems coexisting behind repositories), never a big bang.

## Choosing for a new project (no existing choice)
Default: Riverpod with codegen. Bloc is equally valid when the team values
explicit events and traceability. State the choice and the reason.
