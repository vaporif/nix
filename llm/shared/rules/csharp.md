---
globs: "**/*.cs"
---

# C# (Unity)

- Every type lives in a namespace mirroring the folder path (`MyGame.Combat`) — the global namespace collides with third-party plugins
- `sealed` by default — seal anything not explicitly designed for inheritance (IL2CPP devirtualization, clearer intent)
- Explicit access modifiers everywhere — never rely on the implicit default
- Fields are `[SerializeField] private`, never `public` — expose state via properties with the narrowest setter (`get`-only or `private set`)
- Document `[SerializeField]` fields with `[Tooltip("...")]`, not `//` — the tooltip is where designers actually read it
- `System.Action` / C# events over `UnityEvent` for code-to-code messaging; raise through a controlled `OnX()` method
- Name events as verb phrases — past tense after (`DoorOpened`), present participle before (`OpeningDoor`)
- `readonly struct` / `record` for small immutable value data; make illegal states unrepresentable
- Nullable reference types on; `T?` + `TryGet(out T)` is the idiomatic "maybe a value" — reach for a hand-rolled `readonly struct Option<T>` only when you need composition
- Never wrap `UnityEngine.Object` in an Option/null abstraction — a destroyed object is fake-null (`== null` is overloaded) and reads as `Some` while behaving `None`
- Exceptions for exceptional failures only; expected failure returns `Result`/`TryGet`. Never swallow — `Debug.LogError`/`LogException` with context or propagate
- Validate at boundaries: save data, network payloads, Inspector-assigned references (null-guard in `Awake`)

## MonoBehaviour

- Keep logic in plain C# classes — MonoBehaviours are thin adapters that wire components and delegate
- Lifecycle: `Awake` self-setup and component caching, `OnEnable`/`OnDisable` event (un)subscription, `Start` cross-object refs, `OnDestroy` teardown
- Unsubscribe in `OnDisable`/`OnDestroy` everything subscribed — dangling delegates keep objects alive
- Delete empty `Update`/`FixedUpdate`/`LateUpdate` — Unity still crosses the interop boundary for every declared one
- Prefer `TryGetComponent(out var c)` over `GetComponent` + null check — avoids an Editor allocation when absent
- Never call `GetComponent`/`Find`/`Camera.main` from `Update` — cache in `Awake`
- Never assume cross-object execution order — use `Start` or explicit init, or set Script Execution Order deliberately

## Architecture

- Assembly definitions (`.asmdef`) per module — faster incremental compiles, enforced dependency direction; runtime and editor code in separate assemblies
- Group folders by gameplay domain (`Combat/`, `Inventory/`, `UI/`), not by type (`Managers/`, `Scripts/`)
- Dependency injection over singletons and `FindObjectOfType` — wire the object graph in one composition root; keep genuine engine services behind an interface
- ScriptableObjects for shared designer-tunable data (enemy stats, tuning tables) and for decoupled event channels
- Enum + `switch` expression is the FSM that ships — formal state classes only when states carry real per-state behavior and data
- Object pooling is mandatory for anything spawned repeatedly

## Performance

- Profile first — Unity Profiler and `ProfilerMarker`. Never optimize on a hunch or claim a speedup you did not measure
- Zero allocations in `Update`/`FixedUpdate` and hot paths: no `new` collections, no LINQ, no string concatenation, no boxing
- Cache yield instructions — one `WaitForSeconds` field reused, not `new` per iteration
- `CompareTag("X")` instead of `gameObject.tag == "X"` — the getter allocates
- Non-allocating physics: `Physics.RaycastNonAlloc` / `OverlapSphereNonAlloc` into a preallocated buffer
- `MaterialPropertyBlock` for per-renderer shader values — `renderer.material.x` instantiates and leaks a material and breaks batching
- Batch over per-object `Update` — one manager iterating N entities beats N MonoBehaviours, and sets up jobification
- Jobs + `[BurstCompile]` for hot math/simulation — feed `NativeArray<T>`/`NativeList<T>` and dispose them; no full DOTS adoption required
- `Span<T>`/`stackalloc` for transient buffers; avoid `virtual` in hot paths; no finalizers or runtime reflection
- Cache `Camera.main` (runs `FindGameObjectsWithTag`) and `transform` in tight loops

## Testing

- Unity Test Framework: EditMode for plain C# logic (fast, no Play mode), PlayMode for MonoBehaviour/coroutine/frame behavior
- Test the POCO logic layer directly — that is the payoff of keeping logic out of MonoBehaviours
- Cover edge cases and error paths, not just the happy path; `[UnityTest]` + `IEnumerator` for frame-stepping assertions

## Toolchain

- `dotnet format` / `.editorconfig` clean before commit — zero analyzer warnings
- Prefer Input System, Addressables, and UI Toolkit over their legacy counterparts on new work
- Verify API signatures against the project's Unity version — the API churns across LTS releases, don't write from memory
