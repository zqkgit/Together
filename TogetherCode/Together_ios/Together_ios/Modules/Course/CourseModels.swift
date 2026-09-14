import Foundation

// MARK: - 课程详情（报名页用）

struct CourseDetail: Codable {
    let course_id: String
    let title: String?
    let price: Int?
    let cover: String?
    let studio: CourseStudio?
    let packages: [PackageItem]?
}

struct CourseStudio: Codable {
    let studio_id: String
    let name: String?
}

struct PackageItem: Codable {
    let package_id: String
    let name: String?
    let lessons: Int?
    let price: Int?
    let original_price: Int?
    let status: Int?
}
