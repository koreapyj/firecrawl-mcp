# patches/

Quilt series applied with `--fuzz=0`. This directory is the quilt patch directory.

Prefer the core's `unstable_hooks` in `src/index.ts` over editing `src/server.ts`: hunks in
large upstream files break with every release.

```sh
make clean prepare QUILT=1
export QUILTRC="$PWD/.quiltrc" QUILT_PATCHES="$PWD/patches"
cd src
quilt new 9002-my-change.patch
quilt add src/index.ts
quilt edit src/index.ts
quilt refresh
```

| Range | Kind |
|---|---|
| `0001`-`0999` | Fixes that could go upstream. |
| `1000`-`1999` | Other. |
| `9000`-`9999` | Local policy. |
