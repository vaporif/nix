---
description: Run vulnix without whitelist, triage findings, add false positives to whitelist
---

Triage vulnix findings by running a full scan without the whitelist and classifying each result.

**Steps:**

1. Read `vulnix-whitelist.toml` to understand what's already triaged
2. Run `vulnix --system` (no `--whitelist` flag) to get ALL findings
3. Parse the output - each finding shows a package name and its CVEs
4. Filter out packages already in the whitelist (already triaged)
5. For each NEW finding not in the whitelist:

**Research each CVE:**
- Search the web for CVE details (NVD, GitHub advisories)
- Determine: is this CVE actually about THIS package, or a name collision?
- Check if the package is build-time only or runtime
- Check if the vulnerability is relevant to our usage

**Classify as FALSE POSITIVE if:**
- Name collision: CVE is for a different software with the same name (e.g., Haskell package vs npm package, Jenkins plugin vs CLI tool)
- Build-time only: package only exists in the build closure, not runtime
- Already patched: nixpkgs version already includes the fix
- Not applicable: vulnerability requires conditions we don't meet (e.g., server-side CVE for a CLI tool)

**Classify as REAL VULNERABILITY if:**
- CVE applies to this exact package and version
- Package is in the runtime closure
- Vulnerability is exploitable in our context
- No patch available yet

6. Present findings in two groups:

**Real vulnerabilities (DO NOT whitelist):**
- Package name, CVEs, severity, description
- Suggested remediation (update nixpkgs, pin version, remove package)

**False positives (will add to whitelist):**
- Package name, CVEs, reason for whitelisting
- Proposed whitelist entry with comment

7. After user approval, add false positive entries to `vulnix-whitelist.toml`:
   - Follow existing file structure and categories
   - Include a descriptive `comment` explaining why it's whitelisted
   - Add specific `cve` list when whitelisting specific CVEs (not the whole package)
   - Place entries in the appropriate section (Haskell, build-time, name collision, transitive)

8. Run `vulnix --system --whitelist vulnix-whitelist.toml` to verify only real vulns remain
