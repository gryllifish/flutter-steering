# Testing guide

## What to test, by layer
| Layer | Test type | Must cover |
|---|---|---|
| Domain (entities, value objects, use cases) | unit | every rule and edge case: empty, boundaries, invalid input |
| Data (DTO mapping, repositories) | unit with fakes/mocks | JSON round trip, mapping, each exception → failure |
| State (controllers, blocs, notifiers) | unit | initial state, success, failure, transitions, side effects |
| Widgets/screens | widget | each visible state (loading, empty, error+retry, data), key interactions, navigation intent |
| Visual contracts (design system, key screens) | golden | light/dark, text scale, locales with long strings |
| Critical journeys (login, checkout) | integration (`integration_test`/Patrol) | happy path on a real engine |

Test behavior through the public API, not implementation details.

## Conventions
- Mirror `lib/` in `test/`: `lib/features/x/data/x_repository.dart` →
  `test/features/x/data/x_repository_test.dart`.
- `group` per unit under test and per method; test names read as sentences:
  `'returns NotFoundFailure when the API responds 404'`.
- Arrange / Act / Assert, one behavior per test.
- Use the project's mocking library (mocktail by default; mockito if already
  used). Prefer hand-written fakes for simple interfaces.
- `registerFallbackValue` in `setUpAll` for mocktail `any()` with custom types.
- Shared builders/fixtures in `test/helpers/` (e.g. `pumpApp` wrapping the
  widget in the app's `MaterialApp`, theme, l10n delegates and
  `ProviderScope`/`BlocProvider`s).
- No real network, disk, clock or randomness: inject `Clock`/`DateTime
  Function()`, seeds and repositories.

## Widget tests
- `pumpWidget` through the shared `pumpApp` helper so theme and l10n match
  production.
- Find by semantics or keys, not by text in a specific language when the
  project is localized (or pin the locale in the helper).
- `pump()` for one frame, `pump(duration)` for animations, `pumpAndSettle()`
  only when there is no infinite animation (progress indicators never settle).
- Verify interactions reach the controller (mock/override it), not the
  controller's internals.

## Riverpod
```dart
final container = ProviderContainer.test(
  overrides: [clientsRepositoryProvider.overrideWithValue(FakeRepo())],
);
await expectLater(
  container.read(clientsControllerProvider.future),
  completion(hasLength(3)),
);
```
For widgets: `ProviderScope(overrides: [...], child: ...)`.

## Bloc
```dart
blocTest<ClientsCubit, ClientsState>(
  'emits [loading, loaded] when fetch succeeds',
  build: () => ClientsCubit(repo),
  setUp: () => when(() => repo.fetch()).thenAnswer((_) async => clients),
  act: (cubit) => cubit.load(),
  expect: () => [const ClientsState.loading(), ClientsState.loaded(clients)],
);
```

## Goldens
- Use the project's golden tool (alchemist, golden_toolkit, or plain
  `matchesGoldenFile`). Load real fonts; goldens are platform-sensitive, so
  generate them on the same OS as CI (or tag and run them only in CI).
- Update with `flutter test --update-goldens <path>` and review the diff
  images before committing.

## Accessibility in tests
```dart
final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(textContrastGuideline));
handle.dispose();
```

## Coverage
`flutter test --coverage` then inspect `coverage/lcov.info` for changed
files. Target: new logic fully covered; coverage % is a signal, not a goal.
Exclude generated files from reports.
