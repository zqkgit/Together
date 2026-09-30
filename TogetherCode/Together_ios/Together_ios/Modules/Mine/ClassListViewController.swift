import UIKit
import SnapKit

/// 班级列表：展示课程下的所有班级，点击进入班级学生
final class ClassListViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let classes: [TeacherCourseClassItem]
    private let courseTitle: String

    init(courseTitle: String, classes: [TeacherCourseClassItem]) {
        self.courseTitle = courseTitle
        self.classes = classes
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "班级列表")
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "班级列表")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupLayout() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(ClassListCell.self, forCellReuseIdentifier: ClassListCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        classes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ClassListCell.reuseID, for: indexPath) as! ClassListCell
        cell.configure(classes[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cls = classes[indexPath.row]
        let vc = ClassStudentsViewController(classId: cls.class_id ?? "", className: cls.name ?? "")
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 班级行 Cell

private final class ClassListCell: UITableViewCell {

    static let reuseID = "ClassListCell"

    private let container = UIView()
    private let nameLabel = UILabel()
    private let countLabel = UILabel()
    private let arrowLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(4)
        }

        nameLabel.font = .appBody(15)
        nameLabel.textColor = Theme.Color.ink
        container.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        countLabel.font = .appBody(13)
        countLabel.textColor = Theme.Color.muted
        container.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.xl)
            $0.centerY.equalToSuperview()
        }

        arrowLabel.font = .appBody(14)
        arrowLabel.textColor = Theme.Color.muted
        arrowLabel.text = ">"
        container.addSubview(arrowLabel)
        arrowLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ item: TeacherCourseClassItem) {
        nameLabel.text = item.name ?? "未命名班级"
        countLabel.text = "\(item.studentCount)人"
    }
}