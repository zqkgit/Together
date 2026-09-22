import UIKit
import SnapKit

/// 课程报名：课程信息卡 + 选择孩子 + 确认下单（课程固定课时与价格，无需选择课时包）
final class CourseEnrollViewController: BaseViewController {

    private let courseId: String

    private var course: CourseDetail?
    private var childList: [ChildItem] = []
    private var classList: [CourseClassItem] = []

    private var selectedChildIndex: Int = -1
    private var selectedClassIndex: Int = -1

    private lazy var tableView = UITableView(frame: .zero, style: .grouped)
    private let courseHeader = CourseEnrollHeaderView()
    private let bottomBar = UIView()
    private let amountLabel = UILabel()
    private let submitButton = UIButton(type: .system)

    init(courseId: String) {
        self.courseId = courseId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupBottomBar()
        setupTableView()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "报名课程")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(EnrollOptionCell.self, forCellReuseIdentifier: "OptionCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = courseHeader

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.layer.shadowColor = UIColor.black.cgColor
        bottomBar.layer.shadowOpacity = 0.06
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        amountLabel.font = .appTitle(18)
        amountLabel.textColor = Theme.Color.clay
        bottomBar.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        submitButton.setTitle("提交报名", for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = .appLabel(16)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = Theme.Radius.button
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        bottomBar.addSubview(submitButton)
        submitButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.width.equalTo(140)
            $0.height.equalTo(46)
        }
    }

    private func loadData() {
        showLoading()
        let group = DispatchGroup()
        var detailError: String?

        group.enter()
        CourseService.fetchDetail(courseId: courseId) { [weak self] course, error in
            self?.course = course
            detailError = error
            group.leave()
        }

        group.enter()
        CourseService.fetchChildren { [weak self] list, error in
            self?.childList = list
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.hideLoading()
            if let error = detailError {
                self.showToast(error)
            }
            self.classList = self.course?.classes ?? []
            self.refreshHeader()
            self.tableView.reloadData()
            self.refreshAmount()
        }
    }

    private func refreshHeader() {
        courseHeader.configure(course: course)
        let width = view.bounds.width
        let size = courseHeader.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        )
        courseHeader.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
        tableView.tableHeaderView = courseHeader
    }

    private func refreshAmount() {
        guard let course else {
            amountLabel.text = ""
            submitButton.alpha = 0.5
            submitButton.isEnabled = false
            return
        }
        if let lessons = course.total_lessons, lessons > 0 {
            amountLabel.text = "\(course.priceText)/\(lessons)节"
        } else {
            amountLabel.text = course.priceText
        }
        let ready = selectedChildIndex >= 0 && selectedClassIndex >= 0
        submitButton.alpha = ready ? 1 : 0.5
        submitButton.isEnabled = ready
    }

    @objc private func didTapSubmit() {
        guard selectedChildIndex >= 0 else {
            showToast("请选择孩子")
            return
        }
        guard selectedClassIndex >= 0 else {
            showToast("请选择上课班级")
            return
        }
        let child = childList[selectedChildIndex]
        let classItem = classList[selectedClassIndex]
        showLoading()
        CourseService.createOrder(
            childId: child.child_id,
            courseId: courseId,
            classId: classItem.class_id
        ) { [weak self] orderId, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.hideLoading()
                if let error {
                    self.showToast(error)
                    return
                }
                guard let orderId else {
                    self.showToast("报名失败，请稍后重试")
                    return
                }
                // 报名成功 → 生成「待收款」订单，进入订单详情线下付款并上传凭证
                self.showToast("报名成功，请线下付款后上传凭证")
                let detail = OrderDetailViewController(orderId: orderId)
                var stack = self.navigationController?.viewControllers ?? []
                if let idx = stack.firstIndex(where: { $0 is CourseEnrollViewController }) {
                    stack.remove(at: idx)
                }
                stack.append(detail)
                self.navigationController?.setViewControllers(stack, animated: true)
            }
        }
    }
}

// MARK: - TableView

extension CourseEnrollViewController: UITableViewDataSource, UITableViewDelegate {
    private enum Section: Int, CaseIterable {
        case children, classes
    }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .children: return childList.count
        case .classes: return classList.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .children: return "选择孩子"
        case .classes: return "选择班级"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 44 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath) as! EnrollOptionCell
        switch Section(rawValue: indexPath.section) {
        case .children:
            let child = childList[indexPath.row]
            cell.configure(
                title: child.nickname ?? "宝宝",
                subtitle: child.ageText,
                selected: indexPath.row == selectedChildIndex
            )
        case .classes:
            let classItem = classList[indexPath.row]
            cell.configure(
                title: classItem.name ?? "未命名班级",
                subtitle: classItem.subtitleText,
                selected: indexPath.row == selectedClassIndex,
                disabled: classItem.isFull,
                disabledText: classItem.isFull ? "已满员" : nil
            )
        default:
            break
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .children:
            selectedChildIndex = indexPath.row
        case .classes:
            let classItem = classList[indexPath.row]
            guard !classItem.isFull else {
                showToast("该班级已满员")
                return
            }
            selectedClassIndex = indexPath.row
        default:
            break
        }
        tableView.reloadData()
        refreshAmount()
    }
}

// MARK: - 课程信息卡

final class CourseEnrollHeaderView: UIView {
    private let titleLabel = UILabel()
    private let studioLabel = UILabel()
    private let priceLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface

        titleLabel.font = .appTitle(18)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        studioLabel.font = .appBody(13)
        studioLabel.textColor = Theme.Color.muted
        addSubview(studioLabel)
        studioLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        priceLabel.font = .appTitle(16)
        priceLabel.textColor = Theme.Color.clay
        addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.top.equalTo(studioLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(course: CourseDetail?) {
        guard let course else { return }
        titleLabel.text = course.title
        studioLabel.text = course.subtitleText
        if let lessons = course.total_lessons, lessons > 0 {
            priceLabel.text = "\(course.priceText)/\(lessons)节"
        } else {
            priceLabel.text = course.priceText
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 单选行

final class EnrollOptionCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(14)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.sub
        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalToSuperview().inset(14)
        }

        checkView.image = UIImage(systemName: "checkmark.circle.fill")
        checkView.tintColor = Theme.Color.brand
        checkView.isHidden = true
        contentView.addSubview(checkView)
        checkView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }
    }

    func configure(title: String?, subtitle: String?, selected: Bool, disabled: Bool = false, disabledText: String? = nil) {
        titleLabel.text = title
        subtitleLabel.text = disabled ? (disabledText ?? "已满员") : subtitle
        checkView.isHidden = !selected
        titleLabel.textColor = selected ? Theme.Color.brand : (disabled ? Theme.Color.muted : Theme.Color.ink)
        subtitleLabel.textColor = disabled ? Theme.Color.muted : Theme.Color.sub
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
