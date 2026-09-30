import Foundation

/// 搜索历史本地存储（UserDefaults，最多 10 条）
final class SearchHistoryManager {

    static let shared = SearchHistoryManager()
    private let key = "search_history"
    private let maxCount = 10

    private init() {}

    var history: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 添加关键词（去重，新词置顶，超限裁剪）
    func add(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = history
        list.removeAll { $0 == trimmed }
        list.insert(trimmed, at: 0)
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))
        }
        UserDefaults.standard.set(list, forKey: key)
    }

    /// 清空全部历史
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}