// Cycle connected HDMI inputs with Carbon hotkeys, without Accessibility permission.

import Foundation
import AppKit
import Carbon.HIToolbox
import Darwin

// MARK: - Logging

func logLine(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("\(ts) \(msg)")
    fflush(stdout)
}

// MARK: - Config

struct Config {
    var ip: String?
    var clientKey: String?
    var mac: String?

    static var dir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/lgtv-hotkeys")
    }
    static var file: URL { dir.appendingPathComponent("config.json") }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: file),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Config()
        }
        let ip = obj["ip"] as? String
        return Config(ip: ip == "" ? nil : ip, clientKey: obj["clientKey"] as? String,
                      mac: obj["mac"] as? String)
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
        var obj: [String: Any] = [:]
        if let ip = ip { obj["ip"] = ip }
        if let k = clientKey { obj["clientKey"] = k }
        if let m = mac { obj["mac"] = m }
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted]) {
            try? data.write(to: Config.file)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Config.file.path)
        }
    }
}

// MARK: - Canonical webOS registration payload (verbatim from lgtv2/pairing.json)

let pairingJSON = #"""
{
  "forcePairing": false,
  "pairingType": "PROMPT",
  "manifest": {
    "manifestVersion": 1,
    "appVersion": "1.1",
    "signed": {
      "created": "20140509",
      "appId": "com.lge.test",
      "vendorId": "com.lge",
      "localizedAppNames": {
        "": "LG Remote App",
        "ko-KR": "리모컨 앱",
        "zxx-XX": "ЛГ Rэмotэ AПП"
      },
      "localizedVendorNames": {
        "": "LG Electronics"
      },
      "permissions": [
        "TEST_SECURE",
        "CONTROL_INPUT_TEXT",
        "CONTROL_MOUSE_AND_KEYBOARD",
        "READ_INSTALLED_APPS",
        "READ_LGE_SDX",
        "READ_NOTIFICATIONS",
        "SEARCH",
        "WRITE_SETTINGS",
        "WRITE_NOTIFICATION_ALERT",
        "CONTROL_POWER",
        "READ_CURRENT_CHANNEL",
        "READ_RUNNING_APPS",
        "READ_UPDATE_INFO",
        "UPDATE_FROM_REMOTE_APP",
        "READ_LGE_TV_INPUT_EVENTS",
        "READ_TV_CURRENT_TIME"
      ],
      "serial": "2f930e2d2cfe083771f68e4fe7bb07"
    },
    "permissions": [
      "LAUNCH",
      "LAUNCH_WEBAPP",
      "APP_TO_APP",
      "CLOSE",
      "TEST_OPEN",
      "TEST_PROTECTED",
      "CONTROL_AUDIO",
      "CONTROL_DISPLAY",
      "CONTROL_INPUT_JOYSTICK",
      "CONTROL_INPUT_MEDIA_RECORDING",
      "CONTROL_INPUT_MEDIA_PLAYBACK",
      "CONTROL_INPUT_TV",
      "CONTROL_POWER",
      "READ_APP_STATUS",
      "READ_CURRENT_CHANNEL",
      "READ_INPUT_DEVICE_LIST",
      "READ_NETWORK_STATE",
      "READ_RUNNING_APPS",
      "READ_TV_CHANNEL_LIST",
      "WRITE_NOTIFICATION_TOAST",
      "READ_POWER_STATE",
      "READ_COUNTRY_INFO",
      "READ_SETTINGS",
      "CONTROL_TV_SCREEN",
      "CONTROL_TV_STANBY",
      "CONTROL_FAVORITE_GROUP",
      "CONTROL_USER_INFO",
      "CHECK_BLUETOOTH_DEVICE",
      "CONTROL_BLUETOOTH",
      "CONTROL_TIMER_INFO",
      "STB_INTERNAL_CONNECTION",
      "CONTROL_RECORDING",
      "READ_RECORDING_STATE",
      "WRITE_RECORDING_LIST",
      "READ_RECORDING_LIST",
      "READ_RECORDING_SCHEDULE",
      "WRITE_RECORDING_SCHEDULE",
      "READ_STORAGE_DEVICE_LIST",
      "READ_TV_PROGRAM_INFO",
      "CONTROL_BOX_CHANNEL",
      "READ_TV_ACR_AUTH_TOKEN",
      "READ_TV_CONTENT_STATE",
      "READ_TV_CURRENT_TIME",
      "ADD_LAUNCHER_CHANNEL",
      "SET_CHANNEL_SKIP",
      "RELEASE_CHANNEL_SKIP",
      "CONTROL_CHANNEL_BLOCK",
      "DELETE_SELECT_CHANNEL",
      "CONTROL_CHANNEL_GROUP",
      "SCAN_TV_CHANNELS",
      "CONTROL_TV_POWER",
      "CONTROL_WOL"
    ],
    "signatures": [
      {
        "signatureVersion": 1,
        "signature": "eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCwXVvE2OOSpDZ58hR+59aFNwYDyjQgKk3auukd7pcegmE2CzPCa0bJ0ZsRAcKkCTJrWo5iDzNhMBWRyaMOv5zWSrthlf7G128qvIlpMT0YNY+n/FaOHE73uLrS/g7swl3/qH/BGFG2Hu4RlL48eb3lLKqTt2xKHdCs6Cd4RMfJPYnzgvI4BNrFUKsjkcu+WD4OO2A27Pq1n50cMchmcaXadJhGrOqH5YmHdOCj5NSHzJYrsW0HPlpuAx/ECMeIZYDh6RMqaFM2DXzdKX9NmmyqzJ3o/0lkk/N97gfVRLW5hA29yeAwaCViZNCP8iC9aO0q9fQojoa7NQnAtw=="
      }
    ]
  }
}
"""#

// MARK: - Pure logic (selftested)

struct TVInput {
    let id: String
    let connected: Bool
}

// "com.webos.app.hdmi3" -> "HDMI_3"; non-HDMI app ids -> nil
func hdmiFromAppId(_ appId: String) -> String? {
    let prefix = "com.webos.app.hdmi"
    guard appId.hasPrefix(prefix) else { return nil }
    let suffix = appId.dropFirst(prefix.count)
    guard !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber }) else { return nil }
    return "HDMI_\(suffix)"
}

// Parse a ssap://tv/getExternalInputList response payload into TVInput records.
func parseInputs(_ payload: [String: Any]) -> [TVInput] {
    guard let devices = payload["devices"] as? [[String: Any]] else { return [] }
    return devices.compactMap { d in
        guard let id = d["id"] as? String else { return nil }
        return TVInput(id: id,
                       connected: d["connected"] as? Bool ?? false)
    }
}

private func hdmiNumber(_ id: String) -> Int {
    Int(id.split(separator: "_").last ?? "") ?? 0
}

// Connected HDMI_* input ids, sorted numerically (HDMI_1, HDMI_2, ...).
func connectedSortedHDMI(_ inputs: [TVInput]) -> [String] {
    inputs.filter { $0.connected && $0.id.hasPrefix("HDMI") }
        .map { $0.id }
        .sorted { hdmiNumber($0) < hdmiNumber($1) }
}

// Next/prev connected input relative to `current`, wrapping. `current` nil (TV is on an
// app or a disconnected input) lands on the first (step>0) or last (step<0) input.
// Returns nil when there is nothing to switch to (no inputs, or already the only one).
func pickTarget(current: String?, connected: [String], step: Int) -> String? {
    guard !connected.isEmpty else { return nil }
    guard let cur = current, let idx = connected.firstIndex(of: cur) else {
        return step > 0 ? connected.first : connected.last
    }
    let n = connected.count
    let target = connected[((idx + step) % n + n) % n]
    return target == cur ? nil : target
}

func wolPacket(mac: String) -> Data? {
    let hex = mac.lowercased().filter { "0123456789abcdef".contains($0) }
    guard hex.count == 12 else { return nil }
    var mbytes = [UInt8]()
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2)
        guard let b = UInt8(hex[i..<j], radix: 16) else { return nil }
        mbytes.append(b)
        i = j
    }
    var pkt = [UInt8](repeating: 0xFF, count: 6)
    for _ in 0..<16 { pkt.append(contentsOf: mbytes) }
    return Data(pkt)
}

// MARK: - Selftest

let fixtureJSON = #"""
{"returnValue":true,"devices":[
 {"id":"HDMI_3","label":"HDMI 3","connected":true,"appId":"com.webos.app.hdmi3"},
 {"id":"HDMI_1","label":"HDMI 1","connected":true,"appId":"com.webos.app.hdmi1"},
 {"id":"HDMI_2","label":"HDMI 2","connected":false,"appId":"com.webos.app.hdmi2"},
 {"id":"HDMI_4","label":"PC","connected":true,"appId":"com.webos.app.hdmi4"},
 {"id":"AV_1","label":"AV","connected":true,"appId":"com.webos.app.externalinput.av1"},
 {"id":"COMP_1","label":"Component","connected":false,"appId":"com.webos.app.externalinput.component"}]}
"""#

func runSelftest() -> Int32 {
    var failures = 0
    func check(_ name: String, _ got: String?, _ want: String?) {
        if got == want { print("  ok   \(name)") }
        else { print("  FAIL \(name): got \(got ?? "nil"), want \(want ?? "nil")"); failures += 1 }
    }
    func checkArr(_ name: String, _ got: [String], _ want: [String]) {
        if got == want { print("  ok   \(name)") }
        else { print("  FAIL \(name): got \(got), want \(want)"); failures += 1 }
    }

    check("appid hdmi1", hdmiFromAppId("com.webos.app.hdmi1"), "HDMI_1")
    check("appid hdmi4", hdmiFromAppId("com.webos.app.hdmi4"), "HDMI_4")
    check("appid empty suffix", hdmiFromAppId("com.webos.app.hdmi"), nil)
    check("appid netflix", hdmiFromAppId("netflix"), nil)
    check("appid livetv", hdmiFromAppId("com.webos.app.livetv"), nil)
    let payload = (try? JSONSerialization.jsonObject(
        with: fixtureJSON.data(using: .utf8)!)) as? [String: Any] ?? [:]
    let inputs = parseInputs(payload)
    check("parse count", String(inputs.count), "6")
    checkArr("parse missing connected", connectedSortedHDMI(parseInputs(["devices": [["id": "HDMI_5"]]])), [])
    let hdmi = connectedSortedHDMI(inputs)
    checkArr("connected sorted", hdmi, ["HDMI_1", "HDMI_3", "HDMI_4"])
    checkArr("connected sorted double digit", connectedSortedHDMI([TVInput(id: "HDMI_2", connected: true), TVInput(id: "HDMI_10", connected: true)]), ["HDMI_2", "HDMI_10"])

    check("next mid", pickTarget(current: "HDMI_3", connected: hdmi, step: 1), "HDMI_4")
    check("next wrap", pickTarget(current: "HDMI_4", connected: hdmi, step: 1), "HDMI_1")
    check("prev wrap", pickTarget(current: "HDMI_1", connected: hdmi, step: -1), "HDMI_4")
    check("next from app", pickTarget(current: nil, connected: hdmi, step: 1), "HDMI_1")
    check("prev from app", pickTarget(current: nil, connected: hdmi, step: -1), "HDMI_4")
    check("next from disconnected", pickTarget(current: "HDMI_2", connected: hdmi, step: 1), "HDMI_1")
    check("single same", pickTarget(current: "HDMI_1", connected: ["HDMI_1"], step: 1), nil)
    check("single from app", pickTarget(current: nil, connected: ["HDMI_1"], step: 1), "HDMI_1")
    check("empty", pickTarget(current: nil, connected: [], step: 1), nil)

    check("wol len", wolPacket(mac: "e4:75:dc:32:d2:8c").map { String($0.count) }, "102")
    check("wol nonhex", wolPacket(mac: "zz:75:dc:32:d2:8c").map { _ in "x" }, nil)
    check("wol short", wolPacket(mac: "e4:75:dc").map { _ in "x" }, nil)
    check("wol long", wolPacket(mac: "e4:75:dc:32:d2:8c:99").map { _ in "x" }, nil)
    if let p = wolPacket(mac: "E4-75-DC-32-D2-8C") {
        let a = [UInt8](p)
        check("wol sync", "\(Int(a[0]))/\(Int(a[5]))", "255/255")
        check("wol mac@6", String(Int(a[6])), "228")
        check("wol mac@101", String(Int(a[101])), "140")
    } else { check("wol build", nil, "ok") }

    print(failures == 0 ? "selftest: all passed" : "selftest: \(failures) FAILURES")
    return failures == 0 ? 0 : 1
}

// MARK: - SSAP websocket client

struct SSAPError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

final class SSAPClient: NSObject, URLSessionWebSocketDelegate {
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var openSem = DispatchSemaphore(value: 0)
    private(set) var isOpen = false
    private var msgId = 0

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // The TV's cert is self-signed; trust it (LAN device control, not a browsing context).
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol proto: String?) {
        isOpen = true
        openSem.signal()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isOpen = false
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !isOpen { openSem.signal() }
        isOpen = false
    }

    func connect(ip: String) -> Bool {
        for urlStr in ["wss://\(ip):3001", "ws://\(ip):3000"] {
            openSem = DispatchSemaphore(value: 0)
            isOpen = false
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 6
            let s = URLSession(configuration: cfg, delegate: self, delegateQueue: OperationQueue())
            let t = s.webSocketTask(with: URL(string: urlStr)!)
            session = s
            task = t
            t.resume()
            _ = openSem.wait(timeout: .now() + 4)
            if isOpen { return true }
            t.cancel()
            s.invalidateAndCancel()
        }
        session = nil
        task = nil
        return false
    }

    func close() {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
        isOpen = false
    }

    private func sendJSON(_ obj: [String: Any]) throws {
        guard let t = task else { throw SSAPError("not connected") }
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let str = String(data: data, encoding: .utf8) else { throw SSAPError("encode failed") }
        let sem = DispatchSemaphore(value: 0)
        var sendErr: Error?
        t.send(.string(str)) { err in
            sendErr = err
            sem.signal()
        }
        guard sem.wait(timeout: .now() + 5) == .success else { throw SSAPError("send timeout") }
        if let e = sendErr { throw SSAPError("send failed: \(e.localizedDescription)") }
    }

    // One websocket receive with a timeout. On timeout the pending receive stays armed and
    // would swallow the next frame, so callers must treat a timeout as fatal for the socket.
    private func receiveJSON(timeout: TimeInterval) -> [String: Any]? {
        guard let t = task else { return nil }
        let sem = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        t.receive { r in
            if case .success(let msg) = r, case .string(let s) = msg,
               let data = s.data(using: .utf8),
               let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                result = obj
            }
            sem.signal()
        }
        guard sem.wait(timeout: .now() + timeout) == .success else { return nil }
        return result
    }

    // Register (handshake). With a stored client key this resolves in one round-trip; with
    // none the TV shows its pairing prompt and we wait up to pairingWait for the user.
    func register(clientKey: String?, pairingWait: TimeInterval = 60,
                  onPrompt: () -> Void) throws -> String {
        guard var payload = (try? JSONSerialization.jsonObject(
            with: pairingJSON.data(using: .utf8)!)) as? [String: Any] else {
            throw SSAPError("bad embedded pairing payload")
        }
        if let k = clientKey { payload["client-key"] = k }
        try sendJSON(["type": "register", "id": "reg_0", "payload": payload])

        var deadline = Date().addingTimeInterval(8)
        var prompted = false
        while Date() < deadline {
            guard let msg = receiveJSON(timeout: deadline.timeIntervalSinceNow + 0.5) else { break }
            let type = msg["type"] as? String ?? ""
            let p = msg["payload"] as? [String: Any] ?? [:]
            if type == "registered" {
                guard let key = p["client-key"] as? String else { throw SSAPError("registered without key") }
                return key
            }
            if type == "error" {
                throw SSAPError("register rejected: \(msg["error"] as? String ?? "unknown") (delete clientKey from ~/.config/lgtv-hotkeys/config.json and press the hotkey again to re-pair)")
            }
            if type == "response", (p["pairingType"] as? String) == "PROMPT", !prompted {
                prompted = true
                deadline = Date().addingTimeInterval(pairingWait)
                onPrompt()
            }
        }
        throw SSAPError(prompted ? "pairing prompt not accepted in time" : "register timed out")
    }

    func request(_ uri: String, payload: [String: Any] = [:], timeout: TimeInterval = 5) throws -> [String: Any] {
        msgId += 1
        let id = "req_\(msgId)"
        try sendJSON(["type": "request", "id": id, "uri": uri, "payload": payload])
        for _ in 0..<5 {
            guard let msg = receiveJSON(timeout: timeout) else { throw SSAPError("no response to \(uri)") }
            guard (msg["id"] as? String) == id else { continue }
            let p = msg["payload"] as? [String: Any] ?? [:]
            if (msg["type"] as? String) == "error" || (p["returnValue"] as? Bool) == false {
                throw SSAPError("\(uri) failed: \(msg["error"] as? String ?? p["errorText"] as? String ?? "unknown")")
            }
            return p
        }
        throw SSAPError("no matching response to \(uri)")
    }
}

// MARK: - Discovery (unicast TCP sweep; this router blocks SSDP multicast)

func localIPv4() -> String? {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addrs) == 0 else { return nil }
    defer { freeifaddrs(addrs) }
    var fallback: String?
    var p = addrs
    while let cur = p {
        let ifa = cur.pointee
        if let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
           (ifa.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 {
            var addr = sockaddr_in()
            memcpy(&addr, sa, MemoryLayout<sockaddr_in>.size)
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: buf)
            let name = String(cString: ifa.ifa_name)
            if name == "en0" { return ip }
            if fallback == nil { fallback = ip }
        }
        p = ifa.ifa_next
    }
    return fallback
}

func probeTCP(_ ip: String, _ port: UInt16, timeoutMs: Int32 = 900) -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { Darwin.close(fd) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return false }
    let flags = fcntl(fd, F_GETFL, 0)
    _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    let rc = withUnsafePointer(to: &addr) { p in
        p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
            Darwin.connect(fd, sp, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    if rc == 0 { return true }
    guard errno == EINPROGRESS else { return false }
    var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
    guard poll(&pfd, 1, timeoutMs) > 0 else { return false }
    var soerr: Int32 = 0
    var len = socklen_t(MemoryLayout<Int32>.size)
    getsockopt(fd, SOL_SOCKET, SO_ERROR, &soerr, &len)
    return soerr == 0
}

func discoverTV() -> [String] {
    guard let my = localIPv4() else { return [] }
    let base = my.split(separator: ".").dropLast().joined(separator: ".")
    let lock = NSLock()
    var hits: [String] = []
    let group = DispatchGroup()
    let gate = DispatchSemaphore(value: 64)
    for i in 1...254 {
        let ip = "\(base).\(i)"
        if ip == my { continue }
        DispatchQueue.global().async(group: group) {
            gate.wait()
            defer { gate.signal() }
            if probeTCP(ip, 3001) || probeTCP(ip, 3000) {
                lock.lock()
                hits.append(ip)
                lock.unlock()
            }
        }
    }
    group.wait()
    return hits.sorted {
        (Int($0.split(separator: ".").last ?? "") ?? 0) < (Int($1.split(separator: ".").last ?? "") ?? 0)
    }
}

private func sendUDP(_ data: Data, host: String, port: UInt16) {
    let fd = socket(AF_INET, SOCK_DGRAM, 0)
    guard fd >= 0 else { return }
    defer { close(fd) }
    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr(host)
    _ = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
        withUnsafePointer(to: &addr) { ap in
            ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(fd, raw.baseAddress, data.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}

func powerOn() -> (ok: Bool, msg: String) {
    let cfg = Config.load()
    guard let mac = cfg.mac, !mac.isEmpty else { return (false, "mac is missing from config") }
    guard let packet = wolPacket(mac: mac) else { return (false, "invalid mac in config") }
    if let ip = localIPv4() {
        let base = ip.split(separator: ".").dropLast().joined(separator: ".")
        sendUDP(packet, host: "\(base).255", port: 9)
    }
    if let ip = cfg.ip { sendUDP(packet, host: ip, port: 9) }
    sendUDP(packet, host: "255.255.255.255", port: 9)
    return (true, "power on: magic packet sent")
}

// MARK: - High-level switch

var cachedClient: SSAPClient?

func teardownClient() {
    cachedClient?.close()
    cachedClient = nil
}

func ensureClient() throws -> SSAPClient {
    if let c = cachedClient, c.isOpen { return c }
    teardownClient()
    var cfg = Config.load()
    if cfg.ip == nil {
        logLine("no TV ip configured; sweeping subnet for webos ports...")
        guard let found = discoverTV().first else { throw SSAPError("no webos TV found on subnet") }
        logLine("found TV candidate at \(found)")
        cfg.ip = found
        cfg.save()
    }
    let ip = cfg.ip!
    guard probeTCP(ip, 3001, timeoutMs: 500) || probeTCP(ip, 3000, timeoutMs: 500) else {
        throw SSAPError("TV unreachable at \(ip)")
    }
    let c = SSAPClient()
    defer { if cachedClient !== c { c.close() } }
    guard c.connect(ip: cfg.ip!) else { throw SSAPError("cannot connect to TV at \(cfg.ip!)") }
    let key = try c.register(clientKey: cfg.clientKey) {
        logLine("TV is showing a pairing prompt - accept it with the LG remote (60s)")
    }
    if key != cfg.clientKey {
        cfg.clientKey = key
        cfg.save()
        logLine("stored new pairing key")
    }
    cachedClient = c
    return c
}

func switchOnce(_ c: SSAPClient, step: Int) throws -> String {
    let listResp = try c.request("ssap://tv/getExternalInputList")
    let connected = connectedSortedHDMI(parseInputs(listResp))
    let fg = try? c.request("ssap://com.webos.applicationManager/getForegroundAppInfo")
    let currentApp = fg?["appId"] as? String
    let current = currentApp.flatMap(hdmiFromAppId)
    guard let target = pickTarget(current: current, connected: connected, step: step) else {
        return "no-op: connected HDMI inputs \(connected), current \(current ?? currentApp ?? "?")"
    }
    _ = try c.request("ssap://tv/switchInput", payload: ["inputId": target])
    return "switched \(current ?? currentApp ?? "?") -> \(target) (of \(connected))"
}

func powerOff(_ c: SSAPClient) throws -> String {
    defer { teardownClient() }
    _ = try c.request("ssap://system/turnOff")
    return "powered off"
}

// One transparent retry with a fresh connection, then one retry after re-discovery
// (the router reshuffles DHCP leases, so the pinned ip can go stale).
func performOperation(_ operation: (SSAPClient) throws -> String) -> (ok: Bool, msg: String) {
    do { return (true, try operation(ensureClient())) } catch {
        teardownClient()
        do { return (true, try operation(ensureClient())) } catch {
            let firstErr = "\(error)"
            teardownClient()
            var cfg = Config.load()
            let hits = discoverTV()
            if let found = hits.first, found != cfg.ip {
                logLine("re-pinning TV ip \(cfg.ip ?? "none") -> \(found)")
                let previousIP = cfg.ip
                cfg.ip = found
                cfg.save()
                do { return (true, try operation(ensureClient())) } catch {
                    cfg = Config.load(); cfg.ip = previousIP; cfg.save()
                    return (false, "fail after re-discovery: \(error)")
                }
            }
            return (false, "fail: \(firstErr) (subnet sweep found \(hits.isEmpty ? "nothing" : hits.joined(separator: ",")))")
        }
    }
}

// MARK: - Hotkeys + daemon

let hkSignature: OSType = 0x4C47_5456 // 'LGTV'
let switchQueue = DispatchQueue(label: "lgtv-hotkeys.switch")
let pendingLock = NSLock()
var pendingCount = 0

func handleHotkey(_ id: UInt32) {
    let arrival = DispatchTime.now().uptimeNanoseconds
    func completion(_ msg: String) {
        let ms = (DispatchTime.now().uptimeNanoseconds - arrival) / 1_000_000
        logLine("\(msg) (\(ms) ms)")
    }
    if id == 3 {
        let r = powerOn()
        completion("hotkey on: \(r.msg)")
        if r.ok { switchQueue.async { teardownClient() } }
        return
    }
    let step = (id == 2) ? 1 : -1
    pendingLock.lock()
    let backlog = pendingCount
    if backlog < 3 { pendingCount += 1 }
    pendingLock.unlock()
    guard backlog < 3 else { return }
    switchQueue.async {
        let r = performOperation { c in
            try id == 4 ? powerOff(c) : switchOnce(c, step: step)
        }
        let action = id == 4 ? "off" : "step \(step > 0 ? "+1" : "-1")"
        completion("hotkey \(action): \(r.msg)")
        pendingLock.lock()
        pendingCount -= 1
        pendingLock.unlock()
    }
}

func registerHotkeys() -> Bool {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                             eventKind: UInt32(kEventHotKeyPressed))
    let rcInstall = InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
        var hk = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject),
                          EventParamType(typeEventHotKeyID), nil,
                          MemoryLayout<EventHotKeyID>.size, nil, &hk)
        handleHotkey(hk.id)
        return noErr
    }, 1, &spec, nil, nil)
    guard rcInstall == noErr else { return false }
    let mods = UInt32(controlKey | shiftKey)
    var refL: EventHotKeyRef?
    var refR: EventHotKeyRef?
    let rcL = RegisterEventHotKey(UInt32(kVK_LeftArrow), mods,
                                  EventHotKeyID(signature: hkSignature, id: 1),
                                  GetEventDispatcherTarget(), 0, &refL)
    let rcR = RegisterEventHotKey(UInt32(kVK_RightArrow), mods,
                                  EventHotKeyID(signature: hkSignature, id: 2),
                                  GetEventDispatcherTarget(), 0, &refR)
    var refU: EventHotKeyRef?
    var refD: EventHotKeyRef?
    let rcU = RegisterEventHotKey(UInt32(kVK_UpArrow), mods,
                                  EventHotKeyID(signature: hkSignature, id: 3),
                                  GetEventDispatcherTarget(), 0, &refU)
    let rcD = RegisterEventHotKey(UInt32(kVK_DownArrow), mods,
                                  EventHotKeyID(signature: hkSignature, id: 4),
                                  GetEventDispatcherTarget(), 0, &refD)
    return rcL == noErr && rcR == noErr && rcU == noErr && rcD == noErr
}

func runDaemon() -> Never {
    let cfg = Config.load()
    logLine("lgtv-hotkeys daemon starting (tv ip: \(cfg.ip ?? "unset"), paired: \(cfg.clientKey != nil))")
    // A bare CFRunLoop does not pump the Carbon event queue in a CLI process (verified:
    // hotkeys registered but never fired). NSApplication.run does; .prohibited keeps the
    // process headless (no Dock icon, no menu bar).
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    guard registerHotkeys() else {
        logLine("FATAL: could not register ctrl+shift+left/right/up/down hotkeys (combo taken, or no GUI session)")
        exit(1)
    }
    logLine("hotkeys: ctrl+shift+left = prev HDMI, ctrl+shift+right = next HDMI, ctrl+shift+up = power on, ctrl+shift+down = power off")
    switchQueue.async {
        guard cfg.ip != nil, cfg.clientKey != nil else { return }
        do { _ = try ensureClient() }
        catch { logLine("warm-up failed: \(error)") }
    }
    app.run()
    exit(0)
}

// MARK: - Commands

func cmdSwitch(_ step: Int) -> Int32 {
    let r = performOperation { try switchOnce($0, step: step) }
    logLine(r.msg)
    teardownClient()
    return r.ok ? 0 : 1
}

func cmdPower(_ on: Bool) -> Int32 {
    let r = on ? powerOn() : performOperation(powerOff)
    logLine(r.msg)
    teardownClient()
    return r.ok ? 0 : 1
}

let usage = """
lgtv-hotkeys <command>
  daemon    run the hotkey daemon (ctrl+shift+left/right cycle HDMI, up/down power on/off)
  next      switch TV to next connected HDMI input
  prev      switch TV to previous connected HDMI input
  on        power TV on with Wake-on-LAN
  off       power TV off
  selftest  run the pure-logic test suite
"""

let cmd = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "help"
switch cmd {
case "selftest": exit(runSelftest())
case "next": exit(cmdSwitch(1))
case "prev": exit(cmdSwitch(-1))
case "on": exit(cmdPower(true))
case "off": exit(cmdPower(false))
case "daemon": runDaemon()
default: print(usage); exit(cmd == "help" ? 0 : 2)
}
