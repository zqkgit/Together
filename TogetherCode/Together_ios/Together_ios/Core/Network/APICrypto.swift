import Foundation
import Security
import CryptoKit
import SwiftyJSON

/// 接口加密工具：RSA-OAEP(SHA256) 传输会话密钥 + AES-256-GCM 加密/解密
/// 与后端 `src/middlewares/encrypt.js` 协议对齐
enum APICrypto {

    struct Session {
        let key: Data          // 32B AES 会话密钥
        let encKey: String     // RSA 加密后的密钥（base64，放 X-Enc-Key）
        let nonce: String      // 重放 nonce（16B base64，放 X-Enc-Nonce）
        let timestamp: String  // 秒级时间戳（放 X-Enc-Timestamp）
    }

    /// 生成一次请求的会话（每次请求独立密钥，服务端私钥才能解开）
    static func makeSession() -> Session? {
        guard !APIConfig.apiEncryptPublicKey.isEmpty,
              let keyData = Data(base64Encoded: APIConfig.apiEncryptPublicKey),
              let pubKey = SecKeyCreateWithData(
                keyData as CFData,
                [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary,
                nil
              ) else { return nil }

        var sessionKey = Data(count: 32)
        let status = sessionKey.withUnsafeMutableBytes { raw in
            SecRandomCopyBytes(kSecRandomDefault, 32, raw.baseAddress!)
        }
        guard status == errSecSuccess else { return nil }

        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            pubKey,
            .rsaEncryptionOAEPSHA256,
            sessionKey as CFData,
            &error
        ) as Data? else { return nil }

        var nonce = Data(count: 16)
        _ = nonce.withUnsafeMutableBytes { raw in
            SecRandomCopyBytes(kSecRandomDefault, 16, raw.baseAddress!)
        }

        return Session(
            key: sessionKey,
            encKey: encrypted.base64EncodedString(),
            nonce: nonce.base64EncodedString(),
            timestamp: String(Int(Date().timeIntervalSince1970))
        )
    }

    /// AES-256-GCM 加密（返回 {ct, tag, nonce}，与后端一致）
    static func encryptBody(_ parameters: [String: Any], session: Session) -> [String: Any]? {
        guard let data = try? JSONSerialization.data(withJSONObject: parameters),
              let sealed = try? AES.GCM.seal(data, using: SymmetricKey(data: session.key)) else { return nil }
        return [
            "payload": [
                "ct": sealed.ciphertext.base64EncodedString(),
                "tag": sealed.tag.base64EncodedString(),
                "nonce": sealed.nonce.withUnsafeBytes { Data($0) }.base64EncodedString()
            ]
        ]
    }

    /// 响应 data 可能为字符串（后端 JSON.stringify 后返回）或对象，统一取出 payload 字典
    static func payloadDict(from json: JSON) -> [String: Any]? {
        if let dict = json.dictionaryObject { return dict }
        if let str = json.string,
           let data = str.data(using: .utf8),
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            return dict
        }
        return nil
    }

    /// AES-256-GCM 解密服务端响应 data
    static func decryptData(_ payload: [String: Any], session: Session) -> JSON? {
        guard let ctB64 = payload["ct"] as? String,
              let tagB64 = payload["tag"] as? String,
              let nonceB64 = payload["nonce"] as? String,
              let ct = Data(base64Encoded: ctB64),
              let tag = Data(base64Encoded: tagB64),
              let nonceData = Data(base64Encoded: nonceB64),
              let nonce = try? AES.GCM.Nonce(data: nonceData),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: ct, tag: tag),
              let plain = try? AES.GCM.open(box, using: SymmetricKey(data: session.key)) else { return nil }
        return JSON(plain)
    }
}
