# Can the `verdict-rule-drift-two-surfaces` prior-art case be traced to a specific commit where the duplication was introduced, revealing if it was an intentional copy-paste or an accidental refactor?

Status: crystallized 2026-09-16 from research line `fail-20260916-Can-the-verdict-rule-drift-two-surfaces-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Can-the-verdict-rule-drift-two-surfaces-.md.

# Crystallized record: `verdict-rule-drift-two-surfaces` prior-art traceability

**Research line:** Can the `verdict-rule-drift-two-surfaces` prior-art case be traced to a specific commit where the duplication was introduced, revealing if it was an intentional copy-paste or an accidental refactor?  
**Lifecycle state:** contracting → crystallized as the line’s lasting record. The line remains in motion on idle hosts; this is not a batched or periodic closure.

## Findings

1. **No specific commit can be grounded from the supplied material.**  
   The available prior material names the research line and related drift/prior-art context, but it does not provide a verified commit hash, diff, file path, or repository state that identifies the introduction of the duplication.

2. **No concrete file paths in this repository or the hngh kernel repository can be cited with confidence.**  
   Because no verified source locations are available in the supplied material, this record does not assert that any particular file contains the duplicated verdict-rule logic.

3. **The origin of the duplication is therefore undetermined.**  
   The distinction between an intentional copy-paste and an accidental refactor cannot be resolved on current evidence. That classification requires direct inspection of the commit history and the duplicated source locations in the hngh kernel repository.

4. **The case name supports only a pattern-level observation, not a commit-level conclusion.**  
   `verdict-rule-drift-two-surfaces` indicates that the line concerns drift or duplication across two surfaces, but it does not establish when, where, or how the duplication was introduced.

5. **Any stronger claim would require direct repository evidence.**  
   A defensible conclusion must come from inspecting the hngh kernel repository at the specified root, `~/Projects/etc/hngh`, and identifying the exact duplicated text, files, and commits involved.

## Evidence required to close the line

| Question | Current status |
|---|---|
| Where are the two duplicated surfaces? | Open; no verified file paths available. |
| Which commit first introduced the duplication? | Open; no commit identified. |
| Was the duplication introduced in one commit or across multiple commits? | Open. |
| Does the introducing commit show intentional copy-paste? | Undetermined. |
| Does the introducing commit show an accidental refactor? | Undetermined. |

## Recommendations

1. **Identify the duplicated source locations first.**  
   In `~/Projects/etc/hngh`, locate the two surfaces where the verdict-rule drift or duplication appears. The search should begin with the exact case name only if that string is known to appear in source, comments, tests, or configuration. If it is a research label rather than source text, use semantic tokens from the duplicated rule itself.

2. **Use commit-history pickaxe searches once candidate strings are known.**  
   Useful starting commands include:

   ```bash
   git log --all --oneline -S 'verdict-rule-drift-two-surfaces'
   git log --all --oneline -G 'verdict[-_ ]rule[-_ ]drift[-_ ]two[-_ ]surfaces'
   git log --all --oneline -G '<exact duplicated rule fragment>'
   ```

   The first search is for the literal case name. The second and third searches should be adapted to the actual duplicated text or identifiers.

3. **Trace the first appearance of both copies.**  
   Once candidate files are identified, inspect their history:

   ```bash
   git log --all --oneline -- <candidate-file>
   git blame -L <start-line>,<end-line> <candidate-file>
   git show <candidate-commit> -- <candidate-file>
   ```

   The key question is whether both duplicated surfaces first appear in the same commit, or whether one surface existed earlier and the other was introduced later.

4. **Classify the introducing commit using diff evidence.**  
   A commit is more likely to represent an intentional copy-paste if:
   - it introduces two near-identical blocks in separate files or modules;
   - the duplicated text is structurally parallel;
   - the commit message, comments, or surrounding changes indicate duplication was deliberate;
   - no shared abstraction or refactor target is present.

   A commit is more likely

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
