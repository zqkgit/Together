import UIKit
import SnapKit

/// 班级学生列表：展示学生 + 剩余课时（班级维度，无排课上下文）
final class ClassStudentsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let classId: String
    private let className: String
    private var students: [TeacherWorkbenchStudent] = []
    private var loading = false

    init(classId: String, className: String) {
        self.classId = classId
        self.className = className
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: className)
        setupLayout()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: className)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupLayout() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(ClassStudentCell.self, forCellReuseIdentifier: ClassStudentCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func loadData() {
        guard !loading else { return }
        loading = true
        TeacherService.fetchClassStudents(classId: classId) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let list):
                self.students = list
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        students.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ClassStudentCell.reuseID, for: indexPath) as! ClassStudentCell
        cell.configure(students[indexPath.row])
        return cell
    }
}

/// 学生行：头像 + 昵称 + 剩余课时
private final class ClassStudentCell: UITableViewCell {

    static let reuseID = "ClassStudentCell"

    private let container = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let remainingLabel = UILabel()

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

        avatarView.backgroundColor = Theme.Color.surfaceAlt
        avatarView.layer.cornerRadius = 20
        avatarView.clipsToBounds = true
        container.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
        }

        avatarLabel.font = .appBody(15)
        avatarLabel.textColor = Theme.Color.wood
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nameLabel.font = .appBody(15)
        nameLabel.textColor = Theme.Color.ink
        container.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        remainingLabel.font = .appBody(13)
        remainingLabel.textColor = Theme.Color.muted
        container.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ student: TeacherWorkbenchStudent) {
        nameLabel.text = student.name
        avatarLabel.text = String(student.name.prefix(1))
        remainingLabel.text = "剩余\(student.remaining)课时"
    }
}
