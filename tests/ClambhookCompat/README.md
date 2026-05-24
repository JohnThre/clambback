# Clambhook Compatibility Test

This opt-in smoke test starts a local clambback server, starts a clambhook
SOCKS5 listener with `protocol = "clambback"`, then verifies TCP and UDP
round trips through both processes.

## Usage

```
CLAMBHOOK_BIN=/path/to/clambhook ./clambhook-compat.sh /path/to/clambback
```

When run through CTest, the test is skipped unless `CLAMBHOOK_BIN` is set.
