// 2026-10-07：MCP 服务管理页（后端 /api/mcp/*）
// 对标 Muse 设置页风格

import SwiftUI

struct MCPServer: Identifiable, Decodable {
    var id: String { name }
    let name: String
    let url: String?
    let enabled: Bool?
    let isTemplate: Bool?

    enum CodingKeys: String, CodingKey {
        case name, url, enabled
        case isTemplate = "is_template"
    }
}

struct MCPView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var servers: [MCPServer] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                Spacer()
                Button {
                    // TODO: 添加 MCP 服务
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("MCP 服务")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    Text("给 AI 接入外部工具和数据源")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    if loading {
                        ProgressView("加载中…")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Button("重试") { Task { await load() } }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else if servers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("暂无 MCP 服务")
                                .font(.system(size: 17, weight: .medium))
                            Text("点击右上角 + 添加")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(servers) { server in
                                mcpRow(server)
                                if server.id != servers.last?.id {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func mcpRow(_ server: MCPServer) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 20))
                .foregroundStyle(.purple)
                .frame(width: 48, height: 48)
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.system(size: 17, weight: .semibold))

                if let url = server.url, !url.isEmpty {
                    Text(url)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    if server.isTemplate == true {
                        Text("模板")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    if server.enabled == true {
                        Text("已启用")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    } else {
                        Text("未启用")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { server.enabled == true },
                set: { _ in /* TODO: 切换启用 */ }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        if let j = try? await auth.json("/api/mcp/servers", method: "GET"),
           let list = j["servers"] as? [[String: Any]] {
            if let data = try? JSONSerialization.data(withJSONObject: list),
               let decoded = try? JSONDecoder().decode([MCPServer].self, from: data) {
                servers = decoded
            }
        } else {
            self.error = "加载失败，请检查连接"
        }
    }
}
