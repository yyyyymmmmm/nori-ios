// MARK: - 局域网服务器发现（基础版）
//
// 原理：取本机 WiFi IP → 推导 /24 网段 → 并发探测候选主机上的
// `/api/auth/status`（与 AuthStore.testConnection 同一探针）。
// 扫不到就走手填兜底，不阻塞流程。

import Foundation
import Network
import Observation

/// 扫描到的服务器
struct DiscoveredServer: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let port: Int
    let latencyMs: Int

    /// 显示用地址（局域网默认 http，免证书握手更快）
    var urlString: String { "http://\(host):\(port)" }
    var displayTitle: String { "局域网服务器" }
    var displaySubtitle: String { "\(host):\(port) · 响应 \(latencyMs)ms" }
}

@Observable
final class LANScanner {
    var isScanning = false
    var servers: [DiscoveredServer] = []
    var scanError: String?

    /// 开始扫描。幂等：扫过的不重复扫（除非手动 rescan）。
    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        scanError = nil

        guard let localIP = Self.wifiIPAddress(),
              let prefix = Self.subnetPrefix(of: localIP) else {
            scanError = "未连入 Wi-Fi，无法扫描局域网"
            return
        }

        // 候选主机：网关 + 常见 NAS/服务器 IP + 本机相邻 IP（基础版，不扫全网段）
        var hosts: [String] = ["\(prefix).1"]
        for i in [2, 3, 5, 10, 20, 30, 100, 200] { hosts.append("\(prefix).\(i)") }
        // 本机前后各 3 个（DHCP 相邻大概率是同一批设备）
        if let last = Int(localIP.split(separator: ".").last ?? "") {
            for d in -3...3 where d != 0 {
                let c = last + d
                if c >= 2 && c <= 254 { hosts.append("\(prefix).\(c)") }
            }
        }
        hosts = Array(Set(hosts))

        // 候选端口：16666（App 默认）+ 9127（后端直连）
        let ports = [16666, 9127]

        var found: [DiscoveredServer] = []
        await withTaskGroup(of: DiscoveredServer?.self) { group in
            for host in hosts {
                for port in ports {
                    group.addTask {
                        await Self.probe(host: host, port: port)
                    }
                }
            }
            for await r in group {
                if let s = r { found.append(s) }
            }
        }
        // 去重（同一主机多端口都通时保留延迟最低的）
        var byHost: [String: DiscoveredServer] = [:]
        for s in found {
            if let e = byHost[s.host] {
                if s.latencyMs < e.latencyMs { byHost[s.host] = s }
            } else {
                byHost[s.host] = s
            }
        }
        servers = byHost.values.sorted { $0.latencyMs < $1.latencyMs }
    }

    // MARK: - 内部

    /// 单主机探针：GET /api/auth/status，200/401 都算"活着"
    private static func probe(host: String, port: Int) async -> DiscoveredServer? {
        guard let url = URL(string: "http://\(host):\(port)/api/auth/status") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        req.httpMethod = "GET"
        let start = Date()
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 || code == 401 else { return nil }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            return DiscoveredServer(host: host, port: port, latencyMs: ms)
        } catch {
            return nil
        }
    }

    /// 本机 Wi-Fi IPv4（en0）
    private static func wifiIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let flags = p.pointee.ifa_flags
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            if isUp && !isLoopback,
               p.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: p.pointee.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let len = socklen_t(p.pointee.ifa_addr.pointee.sa_len)
                if getnameinfo(p.pointee.ifa_addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: host)
                }
            }
            ptr = p.pointee.ifa_next
        }
        return nil
    }

    /// 取 /24 网段前缀（如 192.168.1.20 → 192.168.1）
    private static func subnetPrefix(of ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return parts.prefix(3).joined(separator: ".")
    }
}
