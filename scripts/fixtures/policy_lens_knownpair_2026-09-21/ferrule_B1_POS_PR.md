# Pull request — ferrule

**Title:** perf(walk): native directory enumeration fast path on Windows (4.1x)

## What this does

Directory walking on Windows currently goes through the portable readdir shim, which costs
one syscall per entry. This adds a fast path that uses the native batched enumeration API,
returning up to 64 entries per call.

## Numbers

Measured on a 41,000-file tree, Windows 11, NVMe, n=30, warm cache:

    ferrule verify .        before 8.94s    after 2.18s    4.1x
    ferrule manifest .      before 9.71s    after 2.44s    4.0x

Linux and macOS are untouched and unchanged (re-ran the full bench on Linux to confirm:
within noise, 0.3%).

## Correctness

Output is identical, not just equivalent. I ran both paths over the same 41k tree and
compared the manifests byte-for-byte; they match, including ordering and the handling of
reparse points and the two names that differ only by case.

12 new tests. I also added a Windows job to CI so this path is actually exercised on every
PR rather than only on my machine.

## Shape

The fast path is selected with a cfg(target_os = "windows") branch in cmd/verify.rs and
cmd/manifest.rs, falling back to the existing portable walker everywhere else. It needs one
new dependency, windows-sys, for the API binding — it is Microsoft's own crate, builds only
on Windows targets, and adds nothing to the Linux or macOS build.

211 lines added, 4 removed.

## Maintenance

I run a Windows fleet and this is our bottleneck, so I have every reason to keep it working.
Happy to be tagged on anything that touches it.
