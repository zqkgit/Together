import Foundation
import UIKit
import Alamofire
import SwiftyJSON

// MARK: - 佣金（分销返利）模型
// 口径：平台不碰资金。佣金由工作室线下审核打款，推广人按工作室分别申请、确认到账。

/// 收益总览
struct CommissionSummary: Codable {
    struct WalletInfo: Codable {
        let balance: Double?
        let frozen: Double?
        let withdrawn: Double?
        let debt: Double?
    }
    struct Stats: Codable {
        /// 累计佣金
        let total_commission: Double?
        /// 待申请（佣金已产生、尚未发起领取）
        let receivable_commission: Double?
        /// 申请中（已发起领取、工作室打款/确认流程中）
        let applying_commission: Double?
        /// 已到账（推广人已确认）
        let settled_commission: Double?
    }
    /// 按工作室分组的收益
    struct StudioGroup: Codable {
        let studio_id: String?
        let receivable: Double?
        let applying: Double?
        let settled: Double?
        let total: Double?
        let name: String?
        let cover: String?
    }
    let wallet: WalletInfo?
    let stats: Stats?
    let studios: [StudioGroup]?
}

/// 佣金领取单
struct CommissionWithdrawal: Codable {
    struct UserBrief: Codable {
        let user_id: String?
        let nickname: String?
        let phone: String?
    }
    struct StudioBrief: Codable {
        let studio_id: String?
        let name: String?
        let cover: String?
    }
    /// 领取单内的单笔佣金
    struct CommissionBrief: Codable {
        let commission_id: String?
        let order_id: String?
        let amount: Double?
        /// 费率（整数百分比，如 8 表示 8%）
        let rate: Double?
        let status: Int?
        let status_text: String?
        let created_at: String?
    }
    /// 进度步骤
    struct Step: Codable {
        let title: String?
        let done: Bool?
        let current: Bool?
    }

    let withdraw_id: String?
    let user: UserBrief?
    let studio: StudioBrief?
    let amount: Double?
    let amount_text: String?
    let method: String?
    let method_text: String?
    let account: String?
    /// 0 待工作室审核 / 1 待推广人确认 / 2 已驳回 / 3 已完成
    let status: Int?
    let status_text: String?
    let voucher_images: [String]?
    let reject_reason: String?
    let created_at: String?
    let processed_at: String?
    let confirmed_at: String?
    /// 当前用户（推广人）是否可确认到账
    let can_confirm: Bool?
    let commissions: [CommissionBrief]?
    let steps: [Step]?
}

// MARK: - 佣金服务

enum CommissionService {

    /// 收益总览（含按工作室分组）
    static func fetchSummary(completion: @escaping (Result<CommissionSummary, APIError>) -> Void) {
        APIClient.shared.request("/distribution/commission/summary", method: .get) { result in
            switch result {
            case .success(let json):
                if let summary = JSONKit.decode(CommissionSummary.self, from: json) {
                    completion(.success(summary))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 发起领取：一次领取某工作室全部「待申请」佣金（金额后端自动汇总，不支持部分金额）
    /// - Parameters:
    ///   - studioId: 工作室 ID
    ///   - method: 线下收款方式（wechat/alipay/bank/qrcode/cash/other）
    static func requestWithdraw(
        studioId: String,
        method: String,
        completion: @escaping (Result<CommissionWithdrawal, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/distribution/commission/withdraw",
            method: .post,
            parameters: ["studio_id": studioId, "method": method]
        ) { result in
            switch result {
            case .success(let json):
                if let item = JSONKit.decode(CommissionWithdrawal.self, from: json) {
                    completion(.success(item))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 领取单列表（分页）
    static func fetchWithdrawals(
        page: Int,
        pageSize: Int = 20,
        completion: @escaping (Result<(total: Int, list: [CommissionWithdrawal]), APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/distribution/commission/withdrawals",
            method: .get,
            parameters: ["page": page, "page_size": pageSize],
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([CommissionWithdrawal].self, from: json["list"])
                completion(.success((json["total"].int ?? 0, list)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 领取单详情
    static func fetchWithdrawalDetail(
        id: String,
        completion: @escaping (Result<CommissionWithdrawal, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/distribution/commission/withdrawals/\(id)",
            method: .get
        ) { result in
            switch result {
            case .success(let json):
                if let item = JSONKit.decode(CommissionWithdrawal.self, from: json) {
                    completion(.success(item))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 推广人确认已在线下收到佣金（status=1 待确认 → 3 已完成）
    static func confirmWithdrawal(
        id: String,
        completion: @escaping (Result<CommissionWithdrawal, APIError>) -> Void
    ) {
        APIClient.shared.request(
            "/distribution/commission/withdrawals/\(id)/confirm",
            method: .post
        ) { result in
            switch result {
            case .success(let json):
                if let item = JSONKit.decode(CommissionWithdrawal.self, from: json) {
                    completion(.success(item))
                } else {
                    completion(.failure(.parse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 佣金明细（可按工作室过滤），前端再按课程分组
    static func fetchRecords(
        studioId: String? = nil,
        completion: @escaping (Result<[CommissionRecordItem], APIError>) -> Void
    ) {
        var params: [String: Any] = ["page_size": 100]
        if let studioId { params["studio_id"] = studioId }
        APIClient.shared.request(
            "/distribution/commission/records",
            method: .get,
            parameters: params,
            encoding: URLEncoding.default
        ) { result in
            switch result {
            case .success(let json):
                let list = JSONKit.decodeList([CommissionRecordItem].self, from: json["list"])
                completion(.success(list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 工具

    /// ISO 时间 → "MM-dd HH:mm"（兼容带毫秒 / 不带毫秒）
    static func fmtTime(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MM-dd HH:mm"
        return out.string(from: date)
    }

    /// ISO 时间 → "yyyy-MM-dd HH:mm"
    static func fmtFull(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "-" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "-" }
        let out = DateFormatter()
        out.dateFormat = "yyyy-MM-dd HH:mm"
        return out.string(from: date)
    }

    /// 金额格式化
    static func yuan(_ value: Double?) -> String {
        String(format: "¥%.2f", value ?? 0)
    }
}

// MARK: - 线下收款方式（与后端 payMethods 对齐）

struct PayMethodOption {
    let value: String
    let label: String
    /// 微信 / 支付宝 / 银行 / 收款码
    static let all: [PayMethodOption] = [
        PayMethodOption(value: "wechat", label: "微信转账"),
        PayMethodOption(value: "alipay", label: "支付宝转账"),
        PayMethodOption(value: "bank", label: "银行转账"),
        PayMethodOption(value: "qrcode", label: "收款码"),
        PayMethodOption(value: "cash", label: "现金"),
        PayMethodOption(value: "other", label: "其他")
    ]
}

// MARK: - 领取流程（收益中心 / 工作室详情复用）

extension BaseViewController {
    /// 选择收款方式 → 按工作室发起领取 → 成功后跳领取单详情
    func startCommissionWithdraw(studioId: String) {
        let sheet = ThemeActionSheet(
            title: "选择收款方式（线下结算，平台不经手资金）",
            actions: PayMethodOption.all.map { ($0.label, false) }
        )
        sheet.onSelect = { [weak self] index in
            guard let self else { return }
            let method = PayMethodOption.all[index].value
            self.showLoading("提交中...")
            CommissionService.requestWithdraw(studioId: studioId, method: method) { [weak self] result in
                guard let self else { return }
                self.hideLoading()
                switch result {
                case .success(let item):
                    self.showToast("领取申请已提交，等待工作室打款")
                    NotificationCenter.default.post(name: .commissionUpdated, object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.navigationController?.pushViewController(
                            CommissionWithdrawalDetailViewController(item: item), animated: true
                        )
                    }
                case .failure(let error):
                    self.showToast(error.message)
                }
            }
        }
        present(sheet, animated: false)
    }
}
