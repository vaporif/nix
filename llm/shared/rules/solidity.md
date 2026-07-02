---
globs: "**/*.sol"
---

# Solidity

- Custom errors over `require` with string messages — cheaper gas, better UX
- CEI pattern: Checks → Effects → Interactions — always update state before external calls
- Mark storage variables `immutable` or `constant` wherever possible
- Pin pragma to a specific version — no floating `^` ranges
- NatSpec on all public/external functions: `@notice`, `@param`, `@return`, `@dev`
- Emit events for every state change — they're the primary indexing mechanism
- Use `SafeERC20` (`safeTransfer`, `safeTransferFrom`) for all token interactions
- Prefer `abi.encodeCall` over `abi.encodeWithSelector` — type-safe at compile time
- Access control: OpenZeppelin `Ownable2Step` over `Ownable` — prevents accidental lockout
- Storage layout: pack variables to minimize slots (smaller types adjacent)
- External over public for functions not called internally — saves gas
- Use named return values for complex functions; avoid for simple ones
- Reentrancy: use CEI + `ReentrancyGuard` for external call patterns
- Test with Foundry: `forge test` — use `--via-ir` only for production builds, not test runs (much slower)
- Use `forge snapshot` to track gas costs — fail CI if gas regresses unexpectedly

## Toolchain

- Formatter: `forge fmt`
- Linter: `solhint` or `forge lint`
- Static analysis: `slither` for vulnerability detection in CI
- `forge coverage` to track test coverage
- Prefer `bytes32` over `string` for fixed-length identifiers — cheaper storage

## Security

- Never use `tx.origin` for authentication — use `msg.sender`. `tx.origin` can be phished via intermediary contracts
- `unchecked {}` blocks bypass overflow protection — only use for loop counters or proven-safe arithmetic, never for user input
- Never use spot prices or token balances for pricing — use Chainlink oracles or TWAPs to prevent flash loan manipulation
- Pull over push for ETH transfers — let users withdraw instead of iterating sends. Unbounded loops over arrays are a DoS vector
- Signature replay: always use EIP-712 with `nonce`, `chainId`, and contract address. Invalidate used signatures
- `delegatecall` must match storage layout exactly — one misaligned slot corrupts all downstream state
- Always check return values of low-level `.call()` — `(bool success, ) = addr.call{value: x}("")` and revert on failure
- Upgradeable contracts: no constructors, use `initializer` modifier, reserve storage gaps (`uint256[50] private __gap`)
- Avoid `approve` for ERC-20 — use `increaseAllowance`/`decreaseAllowance` to prevent approval race conditions
- Timelocks on sensitive admin functions — give users time to exit before parameter changes take effect
- Reference SWC Registry (swcregistry.io) for known vulnerability patterns
