import UIKit
import SnapKit

/// 课程报名：课程信息卡 + 选择孩子 + 选择课包 + 确认下单
final class CourseEnrollViewController: BaseViewController {

    private let courseId: String

    private var course: CourseDetail?
    private var childList: [ChildItem] = []
    private var packages: [PackageItem] = []

    private var selectedChildIndex: Int = -1
    private var selectedPackageIndex: Int = -1

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
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Theme.Spacing.m, bottom: 0, right: 0)
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

        submitButton.setTitle("确认报名", for: .normal)
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
        var childrenError: String?

        group.enter()
        CourseService.fetchDetail(courseId: courseId) { [weak self] course, error in
            self?.course = course
            detailError = error
            group.leave()
        }

        group.enter()
        CourseService.fetchChildren { [weak self] list, error in
            self?.childList = list
            childrenError = error
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.hideLoading()
            if let error = detailError ?? childrenError {
                self.showToast(error)
            }
            self.packages = self.course?.packages?.filter { ($0.status ?? 1) == 1 } ?? []
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
        guard selectedPackageIndex >= 0, selectedPackageIndex < packages.count else {
            amountLabel.text = "请选择课包"
            submitButton.alpha = 0.5
            submitButton.isEnabled = false
            return
        }
        let price = packages[selectedPackageIndex].price ?? 0
        amountLabel.text = "¥\(String(format: "%.2f", Double(price) / 100))"
        submitButton.alpha = selectedChildIndex >= 0 ? 1 : 0.5
        submitButton.isEnabled = selectedChildIndex >= 0
    }

    @objc private func didTapSubmit() {
        guard selectedChildIndex >= 0, selectedPackageIndex >= 0 else {
            showToast("请选择孩子和课包")
            return
        }
        let child = childList[selectedChildIndex]
        let package = packages[selectedPackageIndex]
        showLoading()
        CourseService.createOrder(
            childId: child.child_id,
            courseId: courseId,
            packageId: package.package_id
        ) { [weak self] orderId, error in
            guard let self else { return }
            self.hideLoading()
            if let error {
                self.showToast(error)
                return
            }
            self.showToast("报名成功，请尽快支付")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}

// MARK: - TableView

extension CourseEnrollViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? childList.count : packages.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "选择孩子" : "选择课包"
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 44 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath) as! EnrollOptionCell
        if indexPath.section == 0 {
            let child = childList[indexPath.row]
            cell.configure(
                title: child.nickname ?? "宝宝",
                subtitle: nil,
                selected: indexPath.row == selectedChildIndex
            )
        } else {
            let package = packages[indexPath.row]
            let price = package.price ?? 0
            cell.configure(
                title: package.name ?? "课包",
                subtitle: "\(package.lessons ?? 0) 课时 · ¥\(String(format: "%.2f", Double(price) / 100))",
                selected: indexPath.row == selectedPackageIndex
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            selectedChildIndex = indexPath.row
        } else {
            selectedPackageIndex = indexPath.row
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
        studioLabel.text = course.studio?.name
        if let price = course.price, price > 0 {
            priceLabel.text = "¥\(String(format: "%.2f", Double(price) / 100)) 起"
        } else {
            priceLabel.text = "价格咨询"
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

    func configure(title: String?, subtitle: String?, selected: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        checkView.isHidden = !selected
        titleLabel.textColor = selected ? Theme.Color.brand : Theme.Color.ink
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
