# Working in this repository

## Merging

When a change is committed and pushed, open a pull request and merge it into
`main` without waiting to be asked. The owner has given standing approval for
this.

Before merging:

- Wait for CI on the pull request's head commit. Merge only if it is green.
  If it is red, fix the cause first.
- Do not merge over a merge conflict or an unresolved review comment. Resolve
  it, or say what blocks it.

After merging, tell the owner it is merged and give the command to update a
local clone:

```
git checkout main && git pull origin main
```

## Verification

The iOS and macOS app targets cannot be built outside Xcode. Say plainly when
a change was only syntax-checked and not compiled or run.

Core logic lives in `DesqueezeiOS/DesqueezeCore` and is tested with:

```
cd DesqueezeiOS/DesqueezeCore && swift test
```
