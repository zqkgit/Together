import UIKit
import SnapKit

/// 「我教的课程」卡片 Cell（参考 PR：#teacherCourses）
/// 课程名+节数 / 班级人数 / 课程进度条+已消节数 / 三个操作按钮（查看课表·班级学生·发作品消课）
final class MyTeachingCourseCell: UITableViewCell {

    var onViewTimetable: (() -> Void)?
    var onViewStudents: (() -> Void)?
    var onPublishConsume: (() -> Void)?

    private let container = UIView()
    private let titleLabel = UILabel()
    private let classLabel = UILabel()
    private let progressTitleLabel = UILabel()
    private let progressValueLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        container.layer.shadowColor = UIColor.black.withAlphaComponent(0.04).cgColor
        container.layer.shadowOpacity = 1
        container.layer.shadowRadius = 8
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        classLabel.font = .appBody(13)
        classLabel.textColor = Theme.Color.muted
        container.addSubview(classLabel)
        classLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalTo(titleLabel)
        }

        progressTitleLabel.font = .appBody(13)
        progressTitleLabel.textColor = Theme.Color.muted
        progressTitleLabel.text = "课程进度"
        container.addSubview(progressTitleLabel)
        progressTitleLabel.snp.makeConstraints {
            $0.top.equalTo(classLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalTo(titleLabel)
        }

        progressValueLabel.font = .appBody(13)
        progressValueLabel.textColor = Theme.Color.ink
        container.addSubview(progressValueLabel)
        progressValueLabel.snp.makeConstraints {
            $0.trailing.equalTo(titleLabel)
            $0.centerY.equalTo(progressTitleLabel)
        }

        progressTrack.backgroundColor = Theme.Color.bg
        progressTrack.layer.cornerRadius = 2.5
        container.addSubview(progressTrack)
        progressTrack.snp.makeConstraints {
            $0.top.equalTo(progressTitleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalTo(titleLabel)
            $0.height.equalTo(5)
        }

        progressFill.backgroundColor = Theme.Color.brand
        progressFill.layer.cornerRadius = 2.5
        progressTrack.addSubview(progressFill)
        progressFill.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
            $0.width.equalTo(0)
        }

        // 操作按钮行
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        container.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(progressTrack.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(titleLabel)
            $0.height.equalTo(0.5)
        }

        let viewTimetable = makeActionButton(title: "查看课表")
        viewTimetable.addTarget(self, action: #selector(didTapViewTimetable), for: .touchUpInside)
        let viewStudents = makeActionButton(title: "班级学生")
        viewStudents.addTarget(self, action: #selector(didTapViewStudents), for: .touchUpInside)
        let publishConsume = makeActionButton(title: "发作品消课")
        publishConsume.addTarget(self, action: #selector(didTapPublishConsume), for: .touchUpInside)

        container.addSubview(viewTimetable)
        container.addSubview(viewStudents)
        container.addSubview(publishConsume)
        viewTimetable.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom)
            $0.leading.bottom.equalToSuperview()
            $0.height.equalTo(44)
        }
        viewStudents.snp.makeConstraints {
            $0.top.equalTo(viewTimetable)
            $0.leading.equalTo(viewTimetable.snp.trailing)
            $0.width.equalTo(viewTimetable)
            $0.height.equalTo(viewTimetable)
        }
        publishConsume.snp.makeConstraints {
            $0.top.equalTo(viewTimetable)
            $0.leading.equalTo(viewStudents.snp.trailing)
            $0.trailing.bottom.equalToSuperview()
            $0.width.equalTo(viewStudents)
            $0.height.equalTo(viewTimetable)
        }

        for btn in [viewStudents, publishConsume] {
            let v = UIView()
            v.backgroundColor = Theme.Color.line
            btn.addSubview(v)
            v.snp.makeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.width.equalTo(0.5)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(Theme.Color.brand, for: .normal)
        button.titleLabel?.font = .appBody(13)
        return button
    }

    func configure(_ item: TeacherCourseItem) {
        titleLabel.text = item.title?.isEmpty == false
            ? "\(item.title ?? "")·\(item.total)节"
            : "未命名课程·\(item.total)节"
        classLabel.text = item.classText
        progressValueLabel.text = "\(item.consumed)/\(item.total)节·\(item.progressValue)%"
        let ratio = item.total > 0 ? CGFloat(min(item.consumed, item.total)) / CGFloat(item.total) : 0
        progressFill.snp.remakeConstraints {
            $0.top.bottom.leading.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(max(ratio, 0.02))
        }
    }

    @objc private func didTapViewTimetable() { onViewTimetable?() }
    @objc private func didTapViewStudents() { onViewStudents?() }
    @objc private func didTapPublishConsume() { onPublishConsume?() }
}
