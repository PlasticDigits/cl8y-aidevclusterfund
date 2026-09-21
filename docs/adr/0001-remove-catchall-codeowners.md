# ADR 0001: Remove catch-all CODEOWNERS

## Status

Accepted ([#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/issues/2)).

Overview (merge gate, runtime): [`architecture.md`](../architecture.md). Do not
copy that table here. **F2** there is three groups: protection GET (six flags),
merge procedure (**F2-4**), tree contracts (**F2-1**, **F2-6**, **F2-7**).
There is no separate standing issue `#2`; the issues URL and the product PR
share one number.

Sister CAC autoland work is
[#429](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/429).
CAC [#388](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/388)
historically forbade deleting CODEOWNERS;
[cl8y-forgejo#48](https://git.cl8y.com/PlasticDigits/cl8y-forgejo/issues/48)
reversed that. Do not revive the skip. Deploy / spend / custody / policy
expansion:
[agent-control #297](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/297)
— **out of scope**.

Sibling product PRs with the same chore title (hello canary
[#15](https://git.cl8y.com/code/hello/pulls/15), CL8Y-web, DEX, …) are **other
repos**. Do not edit them from this worktree. hello#15 is not a fund iid.

## Outcome

Delete the catch-all `CODEOWNERS` so Forgejo does not plant **official** review
requests on every change. Merge to `main` stays: pull request, Woodpecker
context `ci/woodpecker/pr/woodpecker`, SHA-pinned `Do: merge`, no direct push,
no `force_merge`.

**Land vehicle B:** product PR [#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/2)
(or a successor) ships **S0+S1+S2 on one tip** — copy these two files as-is,
delete `CODEOWNERS`, add **exactly** the README Documentation bullet under
Migration S2. These two files **are** the
post-approval standing contract (Status **Accepted**). Copy them onto the
product tip without rewriting Status and without adding job-process notes.
Merging that PR closes `#2`. Design branch `cac-design-issue-2` is
review/transport only; it is **not** merged as a docs-only PR and is **not**
the product PR.

**Leftover issue (land gate).** Before merge of `#2`, S2 opens one leftover
issue in **`code/cl8y-aidevclusterfund` only** (title, repo, and body template
under Migration). That issue owns S3. Land criterion 5 fails if the issue is
missing, empty, or opened in another repo.

**Leftover-complete** (S3: dated protection GET of the six **F2** flags +
dedicated post-merge plant-check PR `{n}`, close without merge) lives on that
leftover issue. S3 is not a close gate for `#2`.

This repo is a product tree, not the forge #48 canary (`code/hello`). #2 is the
file delete plus in-repo docs/README pointer. It does not re-roll protection
and does not implement CAC autoland.

## Context

`71de31c` added root `CODEOWNERS`:

```
# Request review from trusted maintainers on every change.
# Forgejo CODEOWNERS uses Go regular expressions, not GitHub glob syntax.
# Place this file at the repository root, or in docs/ or .forgejo/.
# Product repos live in org `code` (git.cl8y.com/code/{repo}).

.* @code/maintainers
```

Forgejo uses Go regular expressions, not GitHub globs. Combined with historical
`block_on_official_review_requests`, every PR requested team **maintainers** in
org **code**. That team’s only member is the usual PR author, so self-approve
is 422 and merge is 405. CAC `RECOMMEND: ACCEPT` is not a Forgejo `APPROVED`
review.
[cl8y-agent-control#388](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/388)
skipped the deadlock; it did not remove the file or the protection.

Live proof that the file still plants requests (split by endpoint; same
shape on hello [#15](https://git.cl8y.com/code/hello/pulls/15)):

- **Pulls** (`GET .../pulls/2`): `requested_reviewers_teams` is a non-empty
  array. The plant is `name == "maintainers"` **and** org `code` on **that
  team object** (`organization.username == "code"` or
  `organization.name == "code"`). Do not match `code/maintainers` or
  `@code/maintainers`.
- **Reviews** (`GET .../pulls/2/reviews`): `official: true`,
  `state: "REQUEST_REVIEW"`, `team.name: "maintainers"`,
  `team.organization: null`. Org `code` is **not** on the reviews object.
  **Do not** dereference `team.organization` there. Do not treat `official`
  alone as a plant.

Forgejo `Team.name` is `"maintainers"`, not `"code/maintainers"`.

Fleet protection under #48 is described as
`block_on_official_review_requests=false` (**F2-10**) and
`required_approvals=0` (**F2-9**). This design has **no** dated protection JSON
for `code/cl8y-aidevclusterfund` (unauthenticated GET is 401). Do **not** treat
the leftover request on `#2` as non-blocking from fleet values. It is
non-blocking **only if** a dated GET of **this** repo’s `main` rule shows
**F2-9** and **F2-10**, posted as a comment on product PR `#2` or on the
leftover issue before merge (a VM log is not the artifact). If **F2-10** is
still `true` here, merge is 405; do not land `#2` on an unverified GET. That
leftover request also must not be treated as S3 evidence. Leftover-complete
still requires a repo-admin GET of **this** repo’s `main` rule for all six
flags.

Draft implementation (not this design commit):
`ec4ddcf6f8aad33f0318b4e6493913c0a46b8ecb` on `chore/remove-catchall-codeowners`
deletes the six-line file and does not touch README or copy `docs/`. Incomplete
without S0 files and S2 on that PR (or a successor). That commit has empty
commit statuses (`total_count: 0`).

`origin/main` has no `docs/` tree. Relative README links to ADR 0001 /
architecture 404 unless those two files land on the **same merged tip** as the
README pointer.

Issue body points at forgejo `docs/INVARIANTS.md`. That file may not be on
forgejo `main` yet; treat #48/#50 as source, not a 404. Do not fork INVARIANTS
into this repo.

Open PRs in this repo when #2 was filed: [#1](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/1)
(Renovate onboarding) and #2. Renovate benefits from fewer planted reviews; it
is not a sequencing dep.

## Non-goals

- Forgejo protection JSON / `apply_repo_policy.py` / migrate `_ensure_codeowners`
  / templates ([cl8y-forgejo#48](https://git.cl8y.com/PlasticDigits/cl8y-forgejo/issues/48)
  / [pulls/50](https://git.cl8y.com/PlasticDigits/cl8y-forgejo/pulls/50)).
  Sister-repo `_ensure_codeowners` stays out of this slice; leftover-complete
  still fails if a later apply has put the file back (Failure modes).
- PATCHing branch protection from this tree, including force-push allowlist
  fields and `apply_to_admins` (forge #48).
- CAC autoland predicates, occupying jobs, or `DrainSkip::OfficialReview`
  cleanup ([cl8y-agent-control#429](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/429),
  leftover of #388). Drain comments such as `drain skip: no occupying job…` on
  #2 are **#429**, not a #2 failure.
- Dismissing reviewers from the controller (forbidden substitute in #388).
- Path-specific CODEOWNERS, a second maintainer, or `required_approvals: 1`.
- Deleting or rewriting vendored `smartcontracts/lib/**/.github/CODEOWNERS`
  (OpenZeppelin, forge-std). Those are not Forgejo search paths.
- Adding, enabling, or digest-pinning Woodpecker for this repo. Missing
  `ci/woodpecker/pr/woodpecker` statuses are pre-existing.
- Weakening Gitleaks / frontend vitest / Foundry tests, adding `force_merge`,
  enabling direct `main`, or posting fake commit statuses.
- Render / `frontend/render.yaml`, contract addresses, `PROPOSAL.md` economics,
  sprint docs, or Playwright e2e.
- Coolify deploy, UUID/token changes, or flipping auto-deploy
  ([agent-control #297](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/297)).
- Renovate onboarding ([#1](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/1)).
  Do not close or retarget it.
- Waiting on [hello#15](https://git.cl8y.com/code/hello/pulls/15) or other
  sibling file-delete PRs. Canary is informational, not a fund dep.
- Editing `autonomy.rs` / HMAC, or expanding CAC policy for this ordinary
  design.
- A docs-only PR from `cac-design-issue-2` (vehicle **A**). That branch
  transports design between VMs; it is not a merge vehicle.

## Decision

1. **Delete** root `CODEOWNERS`. Do not leave an empty or comments-only file
   (Forgejo still parses it).
2. **Do not add** `docs/CODEOWNERS`, `.gitea/CODEOWNERS`, or
   `.forgejo/CODEOWNERS`. After land, `test -f` fails on all four paths. None of
   those paths may contain a reviewer rule for any pattern (not only `.*`).
   Vendored lib CODEOWNERS stay.
3. **Keep** the merge gate in [`architecture.md`](../architecture.md) **F2**.
   On the product PR (or successor), copy
   `docs/adr/0001-remove-catchall-codeowners.md` and `docs/architecture.md`
   from the accepted design commit onto that **same tip** **as-is** (already
   Status **Accepted**), then add **one** README Documentation bullet (exact
   line under Migration S2). README remains the product overview (not a stub).
   Keep [`PROPOSAL.md`](../../PROPOSAL.md) as product/economic design. Point at
   `docs/architecture.md` **only** for the merge gate (**F2**), and at this ADR
   for the delete decision. Do not imply CODEOWNERS is what makes merge trusted.
   Do not merge a README that points at those paths until they exist on that
   tip. Do not rewrite `PROPOSAL.md` or its Documentation bullet.
4. **Leave** already-planted official requests on open PRs (including #2 and
   likely #1). Treat them as non-blocking **only if** a dated GET of
   `code/cl8y-aidevclusterfund` `main` shows **F2-9** and **F2-10**, posted as
   a comment on product PR `#2` or on the leftover issue before merge.
   Unauthenticated GET is 401; a VM log is not the artifact. Do not
   dismiss them from CAC. Human dismiss is optional leftover, not AC.
5. **Do not** PATCH branch protection from this repository.
6. **Split land from leftover-complete.** Product PR `#2` (or successor) is
   S0+S1+S2 (vehicle **B**). S3 lives on the leftover issue S2 opens in this
   repo before that merge (template below). Require a **dedicated** post-merge
   plant-check PR. Do not accept `#2`’s own official request, `#1`, or “the
   next natural PR.”

## Component / state / interface changes

| Surface | Change |
| --- | --- |
| `CODEOWNERS` (root) | Remove file. |
| `docs/CODEOWNERS`, `.gitea/CODEOWNERS`, `.forgejo/CODEOWNERS` | Must remain absent (no empty file). |
| Vendored `smartcontracts/lib/**/.github/CODEOWNERS` | Unchanged. |
| `docs/adr/0001-remove-catchall-codeowners.md`, `docs/architecture.md` | Copy as-is onto the product PR so the merged tip is S0+S1+S2. Standing F2 contract lands with the delete. Status on those files is **Accepted**. |
| Forgejo PR review interface | After land, a **dedicated** plant-check PR against `main` must not get an official CODEOWNERS team request. |
| Branch protection API | No write from this ticket. Operator reads must still match architecture **protection GET** (six flags for the `main` rule). In-repo CI cannot perform that GET. Land of `#2` while leftover official requests remain additionally requires a dated GET of **F2-9** and **F2-10** on **this** repo, posted as a comment on product PR `#2` or on the leftover issue before merge (not a VM log). |
| `.woodpecker.yaml` | Must remain absent in this ticket. Do not add one to unblock merge. |
| `frontend/render.yaml`, contracts, vitest/e2e, husky | Unchanged. |
| README | Mandatory on the product PR: **one** Documentation bullet (Migration S2 exact line). Merge gate is **F2** only, documented in `docs/architecture.md`; product/economic design stays [`PROPOSAL.md`](../../PROPOSAL.md). Relative links to ADR 0001 / architecture, which exist on that same tip. Keep the product overview. Do not rewrite the `PROPOSAL.md` bullet. |
| Leftover issue | New issue in `code/cl8y-aidevclusterfund` only, opened before merge of `#2`, body quotes leftover-complete items 1–2. |
| CAC / Render / org team `maintainers` in org `code` | Unchanged. The team may keep existing; it simply is not planted as official review. |

No runtime state, schema, contract ABI, or HTTP API.

## Affected invariants

IDs live in [`architecture.md`](../architecture.md). This ADR changes **F2-1**
(four-path absence). It does not write protection JSON. Leftover-complete
**reads** the six protection flags (**F2-2**, **F2-8**, **F2-3**, **F2-9**,
**F2-10**, **F2-5**). Land does not prove those six GET flags. Land **does**
require a dated GET of **F2-9** and **F2-10** on this repo before treating
leftover official requests as non-blocking, posted as a comment on product
PR `#2` or on the leftover issue (not a VM log). Merge procedure remains **F2-4**.
Render and CAC policy remain **F2-6** and **F2-7**. **F2-2** is
`enable_push == false` (no direct push); it does not claim force-push policy.

Product invariants in `PROPOSAL.md` / `smartcontracts/AUDIT.md` (caps, APR,
matching, upgradeability) are **unchanged**.

## Alternatives

| Option | Why not |
| --- | --- |
| Keep file, rely on `block_on_official_review_requests=false` | Requests still plant on every PR; drain noise; Renovate/agent PRs look like they need a human stamp; templates can re-teach the old gate. |
| Replace `.*` with path owners | No second reviewer exists; same 405/422 if official-review is ever turned on; out of scope. |
| Add a second maintainer | Founder ops, not this implement. |
| Dismiss official requests from CAC | Forbidden by #388 as a substitute for policy reversal. |
| Direct-push the delete to `main` | Violates **F2-2**. File deletes go through a PR (already [#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/2)). |
| Empty or comments-only CODEOWNERS | Forgejo still parses it. Absence is the contract. |
| Whole-tree “no file named CODEOWNERS” | False fail on vendored OpenZeppelin/forge-std `.github/CODEOWNERS`. Four Forgejo paths only. |
| Add `.woodpecker.yaml` in the same PR | Different change (CI enablement). Missing statuses are pre-existing. |
| `force_merge` or fake Woodpecker statuses to land #2 | Forbidden by **F2-4** / **F2-3**. |
| Treat `#2`’s plant, `#1`, or the next natural PR as S3 | Merge closes `#2` before leftover-complete. A dedicated post-merge PR is the evidence. |
| Vehicle **A**: docs-only PR from `cac-design-issue-2` onto `main`, then `#2` as S1+S2 | Second merge vehicle. That branch is design transport, not a product PR. Vehicle **B** puts the two files on the deletion PR so README links resolve on one tip. Draft `ec4ddcf` is not that tip until S0 files and S2 are added. |
| Copy the two files then retitle Status or strip “Proposed” | These files are already Status **Accepted**. Implement copies as-is. |
| Wait on sibling `code/*` CODEOWNERS PRs / hello#15 | Wrong repo; no product iid dependency. |
| Open the leftover issue in `PlasticDigits/*` or leave it empty | Land criterion 5 would pass a wrong-repo or vacant issue. S2 names this repo and quotes leftover-complete items 1–2. |

## Complexity added / removed

**Removed:** catch-all official-review robot on every diff; operator dismiss
step; false “CODEOWNERS is the trusted-PR gate” story in this repo.

**Added:** a small standing doc (this ADR + architecture **F2**) that lands on
`main` via the product PR so later agents do not re-add `.* @code/maintainers`
as a merge requirement, and a leftover issue in this repo that survives merge
of `#2`. No new services, jobs, flags, pipelines, or tests harnesses.

## Migration

1. Fleet protection is owned by forge #48. This ticket does not PATCH. Do not
   treat a GET recorded on `code/hello` as proof for this repo.
2. **Leftover issue (S2, land gate).** Before merging the product PR, open
   **one** follow-up issue in **`code/cl8y-aidevclusterfund` only**. Do not
   open it in `PlasticDigits/cl8y-forgejo`, `PlasticDigits/cl8y-agent-control`,
   or any other repo. Suggested title: `chore: leftover CODEOWNERS S3
   (protection GET + plant-check)`. Body **must quote** leftover-complete
   items 1–2 from this ADR (dated `main` protection GET of the six **F2**
   flags; dedicated post-merge plant-check `{n}`, close without merge). Record
   that issue’s iid on the product PR before merge. Merging
   [#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/2) closes that
   number; S3 must not live only there.

   Body template (quote onto the leftover issue):

   ```
   Leftover-complete for ADR 0001 after merge of product PR #2. This issue
   does not close #2. Opened in code/cl8y-aidevclusterfund before that merge.

   1. Dated operator GET of this repo's `main` protection rule equals the six
      F2 protection flags (F2-2, F2-8, F2-3, F2-9, F2-10, F2-5) in
      docs/architecture.md. Attest the JSON here. Not copied from code/hello.
      A GET recorded before a later template re-copy does not count.

   2. After the delete is on `main`: dedicated plant-check PR {n} (not draft,
      title not WIP, at least one changed file, no manual reviewer request).
      Split matchers by endpoint:
      - Pulls GET .../pulls/{n}: the pulls arm fails on any non-empty
        requested_reviewers_teams. name == "maintainers" plus org code on
        that team object (organization.username == "code" or
        organization.name == "code") only names a CODEOWNERS plant. It is
        not a second pass path. Do not match code/maintainers or
        @code/maintainers.
      - Reviews GET .../pulls/{n}/reviews: a plant is official == true AND
        state == "REQUEST_REVIEW" AND team.name == "maintainers". Do not
        dereference team.organization (it is null). Do not treat official
        alone as a plant.
      Record {n}, then close without merge. Not #2, not #1, not the next
      natural PR.
   ```

3. **Vehicle B.** Land [#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/2)
   (or a successor) whose tip is S0+S1+S2: copy
   `docs/adr/0001-remove-catchall-codeowners.md` and `docs/architecture.md`
   from the accepted commit on `cac-design-issue-2` **as-is**, delete root
   `CODEOWNERS`, add **exactly** this README Documentation bullet (do not
   rewrite the existing `PROPOSAL.md` bullet):

   ```
   - [docs/architecture.md](docs/architecture.md) - Merge gate **F2** only ([ADR 0001](docs/adr/0001-remove-catchall-codeowners.md)). Product/economic design stays [PROPOSAL.md](PROPOSAL.md).
   ```

   `cac-design-issue-2` stays the review/transport branch; do not open it as
   the product PR; do not merge it as docs-only first. Do not merge a README
   that points at those paths until they exist on that tip. Draft `ec4ddcf`
   is not that tip until S0 files and S2 are added.
4. Open PRs created while the file existed (#2, likely #1) may still show an
   official team request. Non-blocking **only if** a dated GET of this repo
   shows **F2-9** and **F2-10**, posted as a comment on product PR `#2` or
   on the leftover issue before merge. Unauthenticated GET is 401; a VM log
   is not the artifact. No bulk dismiss required to land `#2` under that GET.
   If **F2-10** is `true`, stop; merge is 405.
5. Do not restore the file from `docs/templates/CODEOWNERS` in cl8y-forgejo;
   that template is owned by #48.
6. If **F2-8** is true and nothing posts `ci/woodpecker/pr/woodpecker`,
   `Do: merge` of `#2` waits. Missing statuses are #429 / a CI ticket, not a
   merge-gate bypass. This ticket does not add `.woodpecker.yaml`, POST fake
   statuses, or restore CODEOWNERS.

## Observability

Relative reads. Do not log tokens, hosts, or protection-script inventories. Do
not add a Forgejo admin token to Woodpecker, husky, or Render.

**Land GET (F2-9 / F2-10, this repo).** Before merging `#2` while leftover
official requests remain, repo admin of `code/cl8y-aidevclusterfund` attests a
dated JSON of the `main` rule showing **F2-9** (`required_approvals == 0`) and
**F2-10** (`block_on_official_review_requests == false`). Post that JSON as a
**comment on product PR `#2` or on the leftover issue**, before merge. Same
endpoints as the leftover-complete GET. Unauthenticated GET is 401; a VM log
is not the artifact. Fleet #48 / `code/hello` is not this GET. If **F2-10**
is `true`, do not land.

**Protection (operator, leftover-complete).** Repo admin of
`code/cl8y-aidevclusterfund` attests dated JSON of the six protection flags for
the `main` rule onto the leftover issue in this repo.
`GET /api/v1/repos/code/cl8y-aidevclusterfund/branch_protections` (array; pick
`rule_name == "main"`) or
`GET /api/v1/repos/code/cl8y-aidevclusterfund/branch_protections/main`. Pass iff
that rule equals architecture **protection GET** for **F2-2**, **F2-8**,
**F2-3**, **F2-9**, **F2-10**, and **F2-5**. `status_check_contexts` must
**equal** `["ci/woodpecker/pr/woodpecker"]`. Fail if any of those six differ.
Do not compare the Merge API / **F2-4** row (not a protection field). Do not
treat `enable_push == false` as a force-push read. A green husky run, empty
commit statuses, or a Render deploy does not satisfy this read. In-repo CI
cannot perform this GET.

**Plant-check (dedicated post-merge PR, leftover-complete).** Recipe is Tests
item 4. Split matchers by endpoint (live proof: Context, PR `#2` and
hello `#15`). Pass iff **both** arms hold:

- **Pulls** `GET /api/v1/repos/code/cl8y-aidevclusterfund/pulls/{n}` — the
  pulls arm **fails** on any non-empty `requested_reviewers_teams`.
  `name == "maintainers"` plus org `code` on that team object
  (`organization.username == "code"` or `organization.name == "code"`)
  only **names** a CODEOWNERS plant. It is not a second pass path. Do not
  match `code/maintainers` or `@code/maintainers`.
- **Reviews** `GET /api/v1/repos/code/cl8y-aidevclusterfund/pulls/{n}/reviews`
  — a plant is `official == true` **and** `state == "REQUEST_REVIEW"` (`state`,
  not a sibling key) **and** `team.name == "maintainers"`. **Do not**
  dereference `team.organization` (it is `null` on this endpoint). Do not
  treat `official` alone as a plant.

Forgejo `Team.name` is `"maintainers"`, not `"code/maintainers"`. Org `code`
lives on **pulls** `requested_reviewers_teams[].organization`, not on the
reviews object. If `requested_reviewers_teams` is later empty (dismiss) while
a `REQUEST_REVIEW` remains, leftover-complete still fails on the reviews arm.

`{n}` is the dedicated plant-check PR opened **after** the delete is on `main`.
PR `#2`’s own official request does not pass. `#1` does not pass. “The next
natural PR” does not pass. Record `{n}` on the leftover issue, then **close
without merge**.

**CI / deploy.** Required host context remains `ci/woodpecker/pr/woodpecker`
when **F2-8** is true. This tree does not post it today and does not add
`.woodpecker.yaml`. When **F2-8** is true, `Do: merge` of `#2` still requires
green `ci/woodpecker/pr/woodpecker` on that SHA; missing statuses delay
merge. Drain comments such as `drain skip: no occupying job…` are **#429**,
not a #2 failure. Render rebuild on `main` is **F2-6** (existing host), not
leftover-complete.

## Failure modes

| Mode | Handling |
| --- | --- |
| File deleted on a branch but still on `main` | New PRs keep planting official review until the product PR merges. Expected until land. |
| README links ADR/architecture but those files are not on the same tip | 404 after merge. Land fails criterion 2. Vehicle **B**: copy both files onto the product PR before merging README. |
| Copy left in `docs/`, `.gitea/`, or `.forgejo/` (including empty/comments-only) | Forgejo still loads the first existing path and may plant. Land fails **F2-1**; delete those paths too (none exist on current `main`). |
| Implement “fixes” tests by deleting vendored `.github/CODEOWNERS` | Out of scope. Four Forgejo paths only. |
| Whole-tree `git grep` for `.* @` | Hits this ADR after a correct delete, and/or vendored libs. Use the pathspec in Tests item 1. |
| cl8y-forgejo migrate/apply re-copies a template | Sister-repo race ([cl8y-forgejo#48](https://git.cl8y.com/PlasticDigits/cl8y-forgejo/issues/48) `_ensure_codeowners`). Out of this slice. If a later apply re-adds the file, leftover-complete is **not** done: delete again via PR and re-run the plant-check; do not treat a passing GET from before the re-copy as done. Never direct-push `main`. |
| Official request leftover on #2 or #1 | Non-blocking **only if** dated GET of this repo shows **F2-9** / **F2-10**, posted as a comment on PR `#2` or the leftover issue. If **F2-10** is `true`, merge is 405; do not land; do not `force_merge`; optional human dismiss is not a CAC substitute. Not S3 evidence. Not a rollback signal. |
| Land GET attested only in a VM log, or not posted as a comment on PR `#2` or the leftover issue | Fail land criterion 6. Unauthenticated GET is 401; a VM log is not the artifact. |
| Treating merge of `#2` as leftover-complete | Merge closes `#2` before S3. Use the leftover issue in this repo. |
| Leftover issue opened in the wrong repo, or empty | Land fails criterion 5. Open in `code/cl8y-aidevclusterfund` with the quoted body. |
| Plant-check matcher uses `team.name == "code/maintainers"` or `@code/maintainers` | False leftover-complete. `Team.name` is `"maintainers"`. On **pulls**, org `code` is on that team object. Do not match those strings. |
| Reviews matcher requires org on `team.organization` | False leftover-complete. Reviews `team.organization` is `null`; that arm never matches a planted CODEOWNERS review (PR `#2` / hello `#15`). If `requested_reviewers_teams` is later empty (dismiss) while `REQUEST_REVIEW` remains, leftover-complete would wrongly pass. Do not dereference `team.organization` on reviews. |
| Plant-check is draft, title contains WIP, has no changed file, or reviewers were requested in the UI / `POST .../requested_reviewers` | False pass (CODEOWNERS skipped or would not have planted) or false fail (manual team request). Recipe fails closed; open a new probe. |
| Merging the plant-check PR | A `main` push and can rebuild Render. **Close without merge.** |
| Protection silently reverted to official-review true | Merge 405 returns. Out of this repo; re-apply via forge policy, do not `force_merge`. Not proven by scanners. |
| `enable_push` flipped true | **F2-2** regression (direct push). Refuse. Not a force-push claim. |
| Host requires Woodpecker and nothing posts | Delay merge. Missing statuses are [#429](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/429) / a CI ticket, not a merge-gate bypass. Do not restore CODEOWNERS, POST fake statuses, or `force_merge`. This ticket does not add `.woodpecker.yaml`. |
| Pulls leftover-complete treats only maintainers+org `code` as fail | False leftover-complete. Any non-empty `requested_reviewers_teams` fails. Plant identity (`name == "maintainers"` plus org `code` on that team object) only **names** a CODEOWNERS plant. Not a second pass path. |
| Re-adding CODEOWNERS “for safety” in a follow-up | Violates **F2-1**. Reviewers must reject unless a new ADR allowlists path owners. |
| Visitor copy / `render.yaml` / contract addresses / `PROPOSAL.md` sneak into the MR | Fail review. |
| README treats `docs/architecture.md` as product architecture or drops `PROPOSAL.md` | Fail S2. Two architecture docs must not collide. |

## Ordered implementation slices

| Slice | Work | Depends on |
| --- | --- | --- |
| **S0** | This design (ADR 0001 + architecture **F2**), already in landed form (Status **Accepted**). Accepted on `cac-design-issue-2` (review). Files reach `main` by copy-as-is onto the product PR (vehicle **B**), not by merging this branch. | None in `code/cl8y-aidevclusterfund`. |
| **S1** | Delete root `CODEOWNERS`. Confirm `test -f` fails on all four Forgejo paths. Do not touch vendored lib CODEOWNERS. | S0 files present on the **same product-PR tip** (not “S0 accepted” alone). Draft delete already on `chore/remove-catchall-codeowners`. |
| **S2** | README pointer on that **same** tip: keep [`PROPOSAL.md`](../../PROPOSAL.md) as product/economic design; add **exactly** the Documentation bullet under Migration (point at `docs/architecture.md` **only** for the merge gate (**F2**)); do not rewrite the `PROPOSAL.md` bullet; relative links to ADR 0001 / architecture (those files already on the tip); do not imply CODEOWNERS is the trusted-merge gate. Keep the product overview. No Render/Woodpecker/contract edits. Open the leftover issue in **`code/cl8y-aidevclusterfund` only**, before merge, with the body template under Migration. Attest dated **F2-9** / **F2-10** GET of this repo before treating leftover official requests as non-blocking; post the JSON as a comment on product PR `#2` or on the leftover issue (not a VM log). | S0 files on the same tip as S1. Same PR as S1. |
| **S3** | Leftover-complete: repo-admin protection GET of the six flags + dedicated post-merge plant-check PR (tests below). Does **not** close `#2`. | S0+S1+S2 merged to `main`. Tracked on the leftover issue in this repo. |

PR `#2` (or successor) ships **S0+S1+S2**. S2 depends on S0 files being on the
same tip, not only on S1.

Sister repos (not slices of #2, not local `DEPS`): forge #48
protection+templates; CAC #429 autoland occupying job; hello#15 canary.

## Tests

In-repo CI cannot GET branch protection. Do not add a vitest/Foundry case solely
for four-path absence (frontend tests are UI; a whole-tree basename check would
false-fail on vendored libs). Husky still runs gitleaks + frontend `tsc`/vitest
on contributor commits.

1. **Absence (land, F2-1).** After S1, `test -f CODEOWNERS`,
   `test -f docs/CODEOWNERS`, `test -f .gitea/CODEOWNERS`, and
   `test -f .forgejo/CODEOWNERS` all fail. Optional content check, **pathspec
   those four paths only**:
   `git grep -nE '^\.\* @' -- CODEOWNERS docs/CODEOWNERS .gitea/CODEOWNERS .forgejo/CODEOWNERS`
   — no match is pass. Do **not** whole-tree `git grep` (the escaped form
   `git grep -n '^\\.\\* @'` matches nothing even while the catch-all file
   exists; the unescaped `git grep -nE '^\.\* @'` hits this ADR after a correct
   delete, and vendored `.github/CODEOWNERS` are irrelevant).
2. **Existing scanners (land).** Husky gitleaks + frontend `tsc`/`vitest` still
   pass on the product PR if the hook runs. Foundry tests are not in this diff.
   Coolify is unused. Land tests do not add a Woodpecker run this tree cannot
   post; empty commit statuses are not leftover-complete. When **F2-8** is
   true, `Do: merge` still requires green `ci/woodpecker/pr/woodpecker` on
   that SHA (Integration completion).
3. **Protection (leftover-complete, operator read).** Repo admin of
   `code/cl8y-aidevclusterfund` attests dated JSON:
   `GET .../branch_protections` `main` rule equals the six architecture
   **protection GET** flags. Fail if any differ. Not inferred from a green
   scanner. Not compared to the Merge API row. Not copied from `code/hello`.
   **F2-2** pass is `enable_push == false` only.
4. **No new plant (leftover-complete).** After the delete is on `main`, on the
   leftover issue in this repo run this recipe:
   1. Delete already on `main` (**F2-1** still holds; if a later apply
      re-copied the file, delete again via PR first).
   2. Open a **dedicated** plant-check PR. Not draft. Title does not contain
      `WIP`. At least one changed file (any path matches Go `.*`). Do not use
      contract bytecode or `render.yaml` as the probe file.
   3. Do not request users or teams in the UI or via
      `POST .../requested_reviewers`.
   4. Split matchers by endpoint. Pass iff **both**:
      - **Pulls:** the pulls arm **fails** on any non-empty
        `requested_reviewers_teams`. `name == "maintainers"` plus org
        `code` on that team object (`organization.username == "code"` or
        `organization.name == "code"`) only **names** a CODEOWNERS plant.
        It is not a second pass path. Do not match `code/maintainers` or
        `@code/maintainers`.
      - **Reviews:** no review is a plant:
        `official == true` **and** `state == "REQUEST_REVIEW"` **and**
        `team.name == "maintainers"`. **Do not** dereference
        `team.organization` (it is `null`). Do not treat `official` alone
        as a plant.
   5. Record `{n}` on the leftover issue, then **close without merge**.
   Fail if draft/WIP, if the PR has no changed file, if reviewers were requested
   manually, if `requested_reviewers_teams` is non-empty, or if the reviews
   arm finds a plant. Do not use `#2`. Do not use
   `#1`. Do not use “the next natural PR.” Who opens the PR: anyone who can
   create a PR on `code/cl8y-aidevclusterfund`. Who GETs protection (item 3):
   repo admin; not husky; not Render.
5. **Reject still blocks (doc-level).** Do not turn off
   `block_on_rejected_reviews` to “make autoland easier.”
6. **Diff guard (land).** Product PR does not change Solidity sources, deploy
   scripts, `frontend/render.yaml`, visitor copy, or token addresses.
7. **Land GET (F2-9 / F2-10).** If leftover official requests remain on `#2`
   or `#1`, a dated GET of this repo’s `main` rule shows **F2-9** and
   **F2-10** before merge. Post that dated JSON as a comment on product PR
   `#2` or on the leftover issue, before merge. Unauthenticated GET is 401;
   a VM log is not the artifact. Fail closed if missing or if **F2-10** is
   `true`.
8. **README collision (land, S2).** Product PR README still lists
   [`PROPOSAL.md`](../../PROPOSAL.md) as product/economic design (existing
   Documentation bullet unchanged) and adds **exactly** the Migration S2
   bullet: `docs/architecture.md` only for the merge gate (**F2**), with
   relative links to ADR 0001 / architecture.

## Rollout

- Merge vehicle **B**: existing
  [#2](https://git.cl8y.com/code/cl8y-aidevclusterfund/pulls/2) once that
  branch’s tip is S0 files + S1 delete + S2 README **or** a successor PR with
  the same three. Design-only `cac-design-issue-2` must not be opened as the
  product PR and must not be merged first as docs-only.
- Order: fleet protection already owned by #48 → copy S0 files as-is + delete
  file + README via one product PR, leftover issue open in this repo, dated
  **F2-9** / **F2-10** GET of this repo if leftover official requests remain
  (land: dated JSON as a comment on product PR `#2` or the leftover issue;
  not a VM log) → leftover issue remains open → dedicated plant-check PR (close
  without merge) + repo-admin six-flag protection GET (leftover-complete).
- If host-required Woodpecker context is missing, wait for a separate CI issue;
  do not weaken **F2-3** / **F2-8** to land #2.
- Canary role: other `code/*` catch-all deletions may copy this pattern; this
  ADR does not merge those repos. hello#15 is not a gate.
- [#297](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/297): no
  deploy, spend, custody, or CAC policy expansion. Landing #2 does not
  authorize Render config changes or autonomy changes.

## Rollback

Restore the previous `CODEOWNERS` **via PR**, not direct `main`, from
`71de31c` (six-line catch-all). That re-plants official requests. It does
**not** by itself re-enable merge-block
(`block_on_official_review_requests`); restoring the 405 gate is a
forge-policy revert, founder-scoped, and is not a fund rollback step.

Woodpecker / Render rollback is unused: those files are untouched.

If S0 docs need revert, revert via PR together with README so relative links do
not 404.

## Integration completion criteria

### Land (S0+S1+S2) — merge of PR `#2` or successor

All must be true on the merged tip. Criteria 1–6 are the in-tree file/docs
contract for `#2`; they are **not** authorization to merge without **F2-3**.
This is what merging `#2` completes. It does **not** wait for S3.

1. `main` has no CODEOWNERS file at the four Forgejo paths: `test -f` fails on
   `CODEOWNERS`, `docs/CODEOWNERS`, `.gitea/CODEOWNERS`, `.forgejo/CODEOWNERS`
   (**F2-1**). Vendored lib CODEOWNERS may still exist.
2. Merged tip contains `docs/adr/0001-remove-catchall-codeowners.md` and
   `docs/architecture.md`, copied as-is (Status **Accepted**). README relative
   links to those paths resolve. Do not merge a README that points at those
   paths until they exist on that tip.
3. README states the **F2** gate via `docs/architecture.md` using **exactly**
   the Migration S2 Documentation bullet, keeps
   [`PROPOSAL.md`](../../PROPOSAL.md) as product/economic design (existing
   bullet unchanged), and does not imply CODEOWNERS is what makes merge
   trusted. Product overview remains. No stub escape.
4. Diff does not change contracts, `frontend/render.yaml`, visitor copy, or add
   `.woodpecker.yaml`. No `force_merge`, no direct `main`, no CAC
   dismiss-as-merge, no HMAC/`autonomy.rs` edits in the product-PR diff.
5. A leftover issue exists in **`code/cl8y-aidevclusterfund` only**, opened
   before this merge, whose body quotes leftover-complete items 1–2 (dated
   `main` protection GET of the six **F2** flags; dedicated post-merge
   plant-check `{n}`, close without merge). An empty issue or an issue in
   another repo does not satisfy this criterion. Record its iid on the product
   PR.
6. If leftover official requests remain on `#2` or `#1`, a dated GET of this
   repo’s `main` rule shows **F2-9** and **F2-10**. Post that dated JSON as a
   comment on product PR `#2` or on the leftover issue, before merge.
   Unauthenticated GET is 401; a VM log is not the artifact. Do not land on an
   unverified GET. If **F2-10** is `true`, merge is 405; stop.

Green husky on `chore/remove-catchall-codeowners` **before** merge is useful
and not sufficient for leftover-complete. Empty commit statuses on `ec4ddcf`
document the CI gap; they are not leftover-complete. Draft `ec4ddcf` is
incomplete without S0 files and S2.

### Leftover-complete (S3) — leftover issue in this repo; survives merge of `#2`

1. Repo admin of `code/cl8y-aidevclusterfund` attests dated JSON:
   `GET .../branch_protections` `main` rule equals the six architecture
   **protection GET** flags (**F2-2**, **F2-8**, **F2-3**, **F2-9**, **F2-10**,
   **F2-5**). Not the Merge API row. Not inferred from a green scanner. Not
   copied from another repo. A GET recorded before a later template re-copy
   does not count; re-delete via PR and re-run this item plus item 2.
   **F2-2** is `enable_push == false` only.
2. A **dedicated** plant-check PR following Tests item 4: not draft, title not
   WIP, ≥1 changed file, no manual reviewer request. Split matchers by
   endpoint (same as Observability / Tests item 4 / leftover issue body):
   - **Pulls:** the pulls arm **fails** on any non-empty
     `requested_reviewers_teams`. `name == "maintainers"` plus org `code`
     on that team object (`organization.username == "code"` or
     `organization.name == "code"`) only **names** a CODEOWNERS plant. It
     is not a second pass path. Do not match `code/maintainers` or
     `@code/maintainers`.
   - **Reviews:** a plant is `official == true` **and**
     `state == "REQUEST_REVIEW"` **and** `team.name == "maintainers"`. **Do
     not** dereference `team.organization` (it is `null`). Do not treat
     `official` alone as a plant.
   Record `{n}`, then close without merge. `#2`’s own official request does
   not count. `#1` does not count. “The next natural PR” does not count.

Forgejo#50 and CAC#429 may stay open; they are not land or leftover gates for
this tree. Sibling repos landing the same chore, and a Render curl, are not
close gates. This ticket does not add `.woodpecker.yaml`, does not POST fake
statuses, and does not restore CODEOWNERS because CI is missing. When
**F2-8** is true, `Do: merge` of `#2` still requires green
`ci/woodpecker/pr/woodpecker` on that SHA. Missing statuses delay merge;
they are [#429](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/429)
/ a CI ticket, not a merge-gate bypass. Land 1–6 remain the in-tree
file/docs contract, not authorization to merge without **F2-3**.

## Authority

This ADR does not grant deploy, spend, custody, or agent-permission expansion
([cl8y-agent-control#297](https://git.cl8y.com/PlasticDigits/cl8y-agent-control/issues/297)).
Relaxing official-review as a **forge merge gate** is fleet policy under
[cl8y-forgejo#48](https://git.cl8y.com/PlasticDigits/cl8y-forgejo/issues/48);
this ADR only removes the in-tree file that plants requests.
