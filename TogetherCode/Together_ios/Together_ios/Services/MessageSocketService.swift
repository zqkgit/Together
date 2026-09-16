import Foundation
import SwiftyJSON

extension Notification.Name {
    /// 收到新聊天消息：object = ["conversation_id": String, "message": ChatMessage]
    static let chatMessageReceived = Notification.Name("chatMessageReceived")
    /// 连接状态变化：object = ["connected": Bool]
    static let chatSocketStatusChanged = Notification.Name("chatSocketStatusChanged")
}

/// 消息 WebSocket 服务（全局单例）
/// - 登录后 connect()，登出 disconnect()
/// - 服务端 30s ping，URLSessionWebSocketTask 自动回 pong
/// - 断线指数退避重连（1s → 2s → 4s … 封顶 30s），token 失效自动重新拉取
final class MessageSocketService: NSObject, URLSessionWebSocketDelegate {

    static let shared = MessageSocketService()

    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var shouldReconnect = false
    private var isConnecting = false
    private var reconnectDelay: TimeInterval = 1

    private override init() {
        super.init()
    }

    /// 当前是否已连接
    var isConnected: Bool {
        webSocketTask?.state == .running
    }

    /// 登录后调用：建立 WebSocket 连接（幂等）
    func connect() {
        guard TokenManager.shared.isLoggedIn else { return }
        guard !isConnecting else { return }
        if let task = webSocketTask, task.state == .running { return }
        shouldReconnect = true
        reconnectDelay = 1
        establish()
    }

    /// 登出 / 退出登录时调用：断开连接
    func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    // MARK: - 连接

    private func establish() {
        guard shouldReconnect, TokenManager.shared.isLoggedIn, !isConnecting else { return }
        isConnecting = true
        MessageService.fetchWsToken { [weak self] urlString in
            guard let self else { return }
            self.isConnecting = false
            guard self.shouldReconnect, let urlString, let url = URL(string: urlString) else { return }

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
            self.urlSession = session
            let task = session.webSocketTask(with: url)
            self.webSocketTask = task
            task.resume()
            self.receiveLoop()
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handle(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handle(text: text)
                    }
                @unknown default:
                    break
                }
                // 继续接收下一条
                self.receiveLoop()
            case .failure:
                // 连接断开（心跳超时 / 网络切换），走重连
                self.scheduleReconnect()
            }
        }
    }

    private func handle(text: String) {
        guard let json = try? JSON(parseJSON: text) else { return }
        let event = json["event"].stringValue
        switch event {
        case "connected":
            NotificationCenter.default.post(name: .chatSocketStatusChanged, object: ["connected": true])
        case "message":
            let data = json["data"]
            guard let conversationId = data["conversation_id"].string else { return }
            let messageJSON = data
            if let raw = try? messageJSON.rawData(),
               let message = try? JSONDecoder().decode(ChatMessage.self, from: raw) {
                NotificationCenter.default.post(
                    name: .chatMessageReceived,
                    object: ["conversation_id": conversationId, "message": message]
                )
            }
        default:
            break
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        reconnectDelay = 1
        NotificationCenter.default.post(name: .chatSocketStatusChanged, object: ["connected": true])
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        NotificationCenter.default.post(name: .chatSocketStatusChanged, object: ["connected": false])
        scheduleReconnect()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 网络层错误（断网/超时）也触发重连
        if error != nil {
            NotificationCenter.default.post(name: .chatSocketStatusChanged, object: ["connected": false])
            scheduleReconnect()
        }
    }

    // MARK: - 重连

    private func scheduleReconnect() {
        guard shouldReconnect, TokenManager.shared.isLoggedIn, !isConnecting else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.establish()
        }
        reconnectDelay = min(reconnectDelay * 2, 30)
    }
}
