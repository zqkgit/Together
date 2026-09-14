import Foundation
import SwiftyJSON

/// 共享 JSON 解码工具（各 Service 复用；兼容 {list:[]} 分页结构与直接数组/单对象）
enum JSONKit {

    /// 优先从 `json["list"]` 解码分页数组，否则回退直接数组
    static func decodeList<T: Decodable>(_ type: [T].Type, from json: JSON) -> [T] {
        if let list = json["list"].array {
            let data = try? JSONSerialization.data(withJSONObject: list.map { $0.object })
            if let data, let items = try? JSONDecoder().decode([T].self, from: data) {
                return items
            }
        }
        return decode([T].self, from: json) ?? []
    }

    /// 直接数组解码
    static func decode<T: Decodable>(_ type: [T].Type, from json: JSON) -> [T]? {
        guard let data = try? json.rawData() else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }

    /// 单对象解码
    static func decode<T: Decodable>(_ type: T.Type, from json: JSON) -> T? {
        guard let data = try? json.rawData() else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
