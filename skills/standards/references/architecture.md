# Architecture

Default for new projects or projects without a defined structure. In existing
projects, map these concepts onto what is already there.

## Feature-first layout
```
lib/
  app/                 # App widget, router, bootstrap, DI composition root
  core/                # Cross-cutting: theme, l10n, network, errors, utils.
                       # Never imports features/ or app/.
  shared/              # Widgets/providers reused by 2+ features
  features/<feature>/
    domain/            # Entities, value objects, repository interfaces. Pure Dart.
    data/              # DTOs, data sources, repository implementations
    application/       # Controllers / blocs / notifiers (a.k.a. controllers/)
    presentation/      # Screens and widgets
```
Promote code to `shared/` only on the second real use, not in anticipation.

## Data flow
- **Data source**: talks to one thing (HTTP, DB, platform channel). Throws
  typed exceptions (`NetworkException`, `CacheException`...), returns DTOs.
- **DTO**: mirrors the wire format (`fromJson`/`toJson`), lives in `data/`,
  has a `toDomain()` mapper. Never leaks into UI.
- **Repository**: implements a domain interface, maps DTOs to entities and
  exceptions to failures. Returns `Result<T>` / `Either` / throws domain
  failures, whatever the project uses consistently.
- **Controller/Bloc**: orchestrates use cases, exposes immutable UI state
  (loading / data / error), no Flutter imports except where the library
  requires it.
- **UI**: reads state, renders all states (loading, empty, error with retry,
  data), forwards intents.

Add a separate use-case layer only when logic is shared between controllers
or is complex enough to test in isolation; otherwise it is ceremony.

## Errors
```dart
sealed class Failure {
  const Failure();
}
final class NetworkFailure extends Failure { const NetworkFailure(); }
final class NotFoundFailure extends Failure { const NotFoundFailure(); }
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}
```
- Catch at the repository boundary, log once with stack trace, convert.
- The UI maps failures to localized messages with an exhaustive `switch`.
- Set `FlutterError.onError` and `PlatformDispatcher.instance.onError` in
  bootstrap and route them to logging/crash reporting.

## Dependency injection
- Riverpod projects: providers are the DI; override them in tests and in
  `ProviderScope` for flavors.
- Bloc/Provider projects: `RepositoryProvider`/`get_it` at the composition
  root; never call `GetIt.I` inside widgets' build or domain code.
- Constructor injection everywhere below the composition root.

## Configuration and flavors
- Environment values via `--dart-define-from-file` (`config/dev.json`, ...)
  read in one `AppConfig` class. Secrets never in the repo or the binary
  when avoidable.
- Flavors: one `main_<flavor>.dart` per flavor or a single main reading
  `appFlavor`, consistent with native flavors.

## Navigation
- Declarative router (go_router/auto_route) with typed routes when available.
- Route guards/redirects for auth live in the router config, fed by state,
  not in screens.
- Deep links are tested.
