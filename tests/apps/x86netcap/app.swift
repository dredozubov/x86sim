// x86netcap: requests for the network capture tools (net_capture / net_log / net_request / net_mock,
// tests/ax/net_e2e.py). Each "Run" button press makes them again against tests/ax/netserve.py on the host
// (the phone reaches the host's loopback; base URL from the NETCAP_BASE environment variable, default
// http://127.0.0.1:7431) and shows each result in a text with the identifier r-<name>: "<name> <status> <bytes>"
// or "<name> ERR <code>". No X86TEST lines: it is driven from the host.
import Darwin
import SwiftUI

final class Upload: NSObject, URLSessionTaskDelegate {
    var sent: Int64 = 0
    func urlSession(_ s: URLSession, task: URLSessionTask, didSendBodyData _: Int64, totalBytesSent t: Int64, totalBytesExpectedToSend _: Int64) { sent = t }
}

@MainActor
final class Model: ObservableObject {
    @Published var results: [String: String] = [:]
    @Published var runs = 0
    let base = ProcessInfo.processInfo.environment["NETCAP_BASE"] ?? "http://127.0.0.1:7431"
    static let names = ["json", "post", "image", "redirect", "https", "fail", "upload", "ephemeral", "socket"]

    func set(_ n: String, _ s: String) { results[n] = "\(n) \(s)" }

    func run() async {
        runs += 1
        results = [:]
        let shared = URLSession.shared
        await get("json", shared, "\(base)/json")
        // POST JSON
        var r = URLRequest(url: URL(string: "\(base)/echo")!)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("netcap", forHTTPHeaderField: "X-Test")
        r.httpBody = #"{"hello":"world","n":42}"#.data(using: .utf8)
        await fetch("post", shared, r)
        await get("image", shared, "\(base)/image.png")
        await get("redirect", shared, "\(base)/redirect")
        await get("https", shared, "https://example.com/")
        await get("fail", shared, "http://127.0.0.1:1/nothing")
        // an upload task with its own session and delegate (bytes from memory, as a stream to protocols)
        let up = Upload()
        let us = URLSession(configuration: .default, delegate: up, delegateQueue: nil)
        var ur = URLRequest(url: URL(string: "\(base)/upload")!)
        ur.httpMethod = "PUT"
        ur.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        do {
            let (d, resp) = try await us.upload(for: ur, from: Data((0..<4096).map { UInt8($0 & 0xff) }))
            set("upload", "\((resp as? HTTPURLResponse)?.statusCode ?? 0) \(d.count) sent=\(up.sent)")
        } catch { set("upload", "ERR \((error as NSError).code)") }
        us.finishTasksAndInvalidate()
        let eph = URLSession(configuration: .ephemeral)
        await get("ephemeral", eph, "\(base)/json?session=ephemeral")
        eph.finishTasksAndInvalidate()
        socketPing()
    }

    func get(_ n: String, _ s: URLSession, _ u: String) async { await fetch(n, s, URLRequest(url: URL(string: u)!)) }

    func fetch(_ n: String, _ s: URLSession, _ r: URLRequest) async {
        do {
            let (d, resp) = try await s.data(for: r)
            let h = resp as? HTTPURLResponse
            set(n, "\(h?.statusCode ?? 0) \(d.count)" + (h?.url != r.url ? " final=\(h?.url?.path ?? "")" : ""))
        } catch { set(n, "ERR \((error as NSError).code)") }
    }

    /// A raw TCP connection (no URLSession): a connection record, not a request
    func socketPing() {
        guard let port = URL(string: base)?.port else { return set("socket", "ERR no port") }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var a = sockaddr_in()
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = in_port_t(UInt16(port).bigEndian)
        a.sin_addr.s_addr = inet_addr("127.0.0.1")
        let ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard ok == 0 else { close(fd); return set("socket", "ERR \(errno)") }
        let req = "GET /json HTTP/1.0\r\nHost: x\r\n\r\n"
        _ = req.withCString { send(fd, $0, strlen($0), 0) }
        var buf = [UInt8](repeating: 0, count: 65536)
        var total = 0
        while true {
            let k = recv(fd, &buf, buf.count, 0)
            if k <= 0 { break }
            total += k
        }
        close(fd)
        set("socket", "ok \(total)")
    }
}

struct Root: View {
    @StateObject var m = Model()
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("x86netcap").font(.title).bold()
            Button("Run") { Task { await m.run() } }.accessibilityIdentifier("run").buttonStyle(.borderedProminent)
            Text("runs \(m.runs) done \(m.results.count)").accessibilityIdentifier("runs")
            ForEach(Model.names, id: \.self) { n in
                Text(m.results[n] ?? "\(n) …").font(.caption.monospaced()).accessibilityIdentifier("r-\(n)")
            }
            Spacer()
        }.padding()
    }
}

@main
struct X86NetCapApp: App {
    var body: some Scene { WindowGroup { Root() } }
}
