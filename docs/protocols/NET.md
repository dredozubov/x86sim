# Network capture of native apps

An app's network traffic, seen from inside its process: no proxy, no certificate, HTTPS in the clear. Guest side
`host/simnet/simnet.m` (`libsimnet.dylib`) and `host/simshim/compat/simshim_net.c` (part of libsimshim); host side
`tools/launcher/core/src/net.rs`, used by the MCP tools `net_capture`, `net_log`, `net_request`
(`bin/mcp_parts/net.rs`), `x86sim net` (`bin/ax_parts/net.rs`), the browser page and the launcher.

Everything goes through files in the device's data folder, `<device>/data/x86sim-net/` (the guest's
`X86SIM_NET_DIR`, set by `mksimdevice.py`):

```
capture/<bundle id>            capture is on for that app: {"body_limit": <bytes>, "since": <unix time>}
log/<bundle id>-<pid>.jsonl    requests of one process (written by libsimnet)
log/<bundle id>-<pid>.conn.jsonl
                               connections of one process (written by libsimshim)
```

## Loading

libsimshim is in every process. Its constructor `shim_net_init` does nothing unless the executable is a third-party
app or extension (under `.../Containers/Bundle/Application/`) and `capture/<its bundle id>` exists. Then it dlopens
`X86SIM_NET_DYLIB` and calls `simnet_start(capfile, logpath, mockpath, bundle)`, and turns on its connection records.
So capture starts with a launch: `net_capture relaunch=true` restarts the app.

Turning capture off removes the capture file. libsimnet checks it at most every 300 ms (a `stat`) and from then on
answers `canInitWithRequest:` with NO: requests go to the system's loader as if it were not there. Connection records
stop at the next `connect`.

## Requests (libsimnet)

A recording `NSURLProtocol` (`X86NetProtocol`) is registered globally (`+[NSURLProtocol registerClass:]`: the shared
session, NSURLConnection) and put first in every session configuration's `protocolClasses` (the getter of
`NSURLSessionConfiguration` and its CFNetwork subclasses is replaced). Not touched: background configurations (an
identifier: their tasks run in nsurlsessiond), WebSocket and stream tasks, schemes other than http / https, and the
protocol's own inner sessions.

It loads each request itself through an inner `NSURLSession` made from a copy of the app's configuration (cookies,
cache, additional headers, timeouts and TLS settings stay the app's), one inner session per app session, one delegate
for all on a serial queue. What the inner task does goes to the app through the protocol client, on the thread and run
loop mode the load started on:

- response, then data as it arrives (streaming);
- a redirect: handed to the client (`wasRedirectedToRequest:`), which starts the new request (a record of its own) and
  ends this one; the record has `redirect_to`;
- authentication challenges, server trust included: the app's session delegate answers, through
  `NSURLAuthenticationChallengeSender`, and the answer goes back to the inner task;
- an upload's body: a stream (`HTTPBodyStream`) is read whole first, so it can be recorded and sent;
- errors and cancellation (`stopLoading` cancels the inner task).

### Records

One JSON object per line. `k` is the kind; `n` numbers requests within the process; the host's id is `<pid>.<n>`.

- `{"k": "hello", "ts", "pid", "bundle", "process", "body_limit"}`: the first line, when the hook starts.
- `{"k": "start", "n", "ts", "method", "url"}`: a request began (a request without a `req` line is in flight).
- `{"k": "req", "n", "ts", ...}`: a request ended:

| field | |
|---|---|
| `method`, `url`, `final_url` | |
| `req_headers`, `resp_headers` | what was sent (the app's headers and the session's) and received |
| `status`, `mime` | absent when the request failed before a response |
| `req_body`, `resp_body` | text as is; other bytes base64 with `*_b64: true`; cut at the body limit with `*_truncated: true` |
| `req_body_size`, `resp_body_size` | whole sizes |
| `timing` | ms: `dns`, `connect`, `tls`, `send`, `wait`, `receive`, `first_byte` (from `NSURLSessionTaskMetrics`, the network load transaction), `total` (start to end, always) |
| `protocol`, `reused`, `remote`, `tls_version`, `cache` | from the same metrics |
| `error` | `{domain, code, text}`; `cancelled: true` for a cancellation |
| `redirect_to` | the redirect this request was answered with |

## Connections (libsimshim)

For stacks that do not use URLSession (Flutter's dart:io, gRPC, raw sockets), libsimshim interposes `getaddrinfo`
(address -> the host name looked up, the last 128), `connect` (TCP to IPv4 / IPv6) and `close`. At `close`, or at
exit for sockets still open, it reads Linux `TCP_INFO` with a Linux system call (`svc #0xfffe`: guest fds are Linux
fds) for the bytes sent and received, and writes

```
{"k": "conn", "n", "ts", "proto": "tcp", "host", "addr", "port", "bytes_out", "bytes_in", "bytes_known", "duration_ms", "end": "close"|"exit"}
```

The host's id is `<pid>.c<n>`. No content. URLSession's own connections show up too when Network.framework connects
with `connect`. UDP is not recorded.
