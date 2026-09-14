import UIKit
import SnapKit

/// 添加孩子表单（PR 图5）：头像选择 / 昵称 / 出生年份 / 性别 / 兴趣多选 / 绑定学籍 / 保存
final class AddChildViewController: BaseViewController {

    var onSaved: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 头像
    private let avatarOptions = ["🌻", "🦊", "🐟", "🍀", "🎀"]
    private var avatarViews: [UIView] = []
    private var selectedAvatar = "🌻"

    // 昵称
    private let nicknameField = UITextField()

    // 出生年份（2010-2024）
    private let birthLabel = UILabel()
    private let birthPicker = UIPickerView()
    private let years: [Int] = Array((2010...2024).reversed())
    private var selectedYear = 2019

    // 性别
    private let interests = ["水彩", "黏土", "书法", "国画", "儿童画", "素描"]
    private var selectedInterests: Set<String> = []
    private var genderButtons: [UIButton] = []
    private var selectedGender = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.title = "添加孩子"
        let close = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapClose))
        close.tintColor = Theme.Color.ink
        navigationItem.rightBarButtonItem = close
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(view)
        }

        var lastView: UIView?

        // 头像选择
        lastView = sectionTitle("选一个头像", below: nil)
        lastView = buildAvatarRow(below: lastView)

        // 昵称
        lastView = sectionTitle("孩子昵称", below: lastView)
        lastView = buildTextFieldRow(below: lastView)

        // 出生年份
        lastView = sectionTitle("出生年份", below: lastView)
        lastView = buildBirthRow(below: lastView)

        // 性别
        lastView = sectionTitle("性别", below: lastView)
        lastView = buildGenderRow(below: lastView)

        // 兴趣方向
        lastView = sectionTitle("兴趣方向（可多选）", below: lastView)
        lastView = buildInterestRow(below: lastView)

        // 绑定学籍
        lastView = buildStudioRow(below: lastView)

        // 保存
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("保存孩子档案", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .appSection(16)
        saveButton.backgroundColor = Theme.Color.brand
        saveButton.layer.cornerRadius = Theme.Radius.button
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        contentView.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.top.equalTo(lastView!.snp.bottom).offset(Theme.Spacing.xxl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.xxl)
        }
    }

    // MARK: - 区块构建

    private func sectionTitle(_ text: String, below: UIView?) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            if let below {
                make.top.equalTo(below.snp.bottom).offset(Theme.Spacing.xl)
            } else {
                make.top.equalToSuperview().offset(Theme.Spacing.xl)
            }
        }
        return label
    }

    private func buildAvatarRow(below: UIView?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.l
        row.distribution = .fillEqually
        contentView.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(60)
        }

        for (index, emoji) in avatarOptions.enumerated() {
            let container = UIView()
            container.layer.cornerRadius = 24
            container.layer.borderWidth = 2
            container.layer.borderColor = (index == 0 ? Theme.Color.brand : UIColor.clear).cgColor
            container.backgroundColor = (index == 0 ? Theme.Color.brandSoft : Theme.Color.surfaceAlt)
            container.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapAvatar(_:)))
            container.addGestureRecognizer(tap)

            let label = UILabel()
            label.text = emoji
            label.font = .systemFont(ofSize: 26)
            label.textAlignment = .center
            container.addSubview(label)
            label.snp.makeConstraints { $0.edges.equalToSuperview() }
            container.tag = index

            row.addArrangedSubview(container)
            avatarViews.append(container)
        }
        return row
    }

    private func buildTextFieldRow(below: UIView?) -> UIView {
        let field = nicknameField
        field.placeholder = "如：糖糖"
        field.font = .appBody(15)
        field.backgroundColor = Theme.Color.surface
        field.layer.cornerRadius = Theme.Radius.input
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.Color.line.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 40))
        field.leftViewMode = .always
        field.returnKeyType = .done
        field.delegate = self
        contentView.addSubview(field)
        field.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(46)
        }
        return field
    }

    private func buildBirthRow(below: UIView?) -> UIView {
        birthLabel.font = .appBody(15)
        birthLabel.textColor = Theme.Color.ink
        birthLabel.text = "\(selectedYear)年（\(age(for: selectedYear))）"
        birthLabel.textAlignment = .center
        birthLabel.backgroundColor = Theme.Color.surface
        birthLabel.layer.cornerRadius = Theme.Radius.input
        birthLabel.layer.masksToBounds = true
        birthLabel.layer.borderWidth = 1
        birthLabel.layer.borderColor = Theme.Color.line.cgColor
        birthLabel.isUserInteractionEnabled = true
        birthLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBirth)))
        contentView.addSubview(birthLabel)
        birthLabel.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.equalTo(160)
            $0.height.equalTo(46)
        }

        birthPicker.delegate = self
        birthPicker.dataSource = self
        if let index = years.firstIndex(of: selectedYear) {
            birthPicker.selectRow(index, inComponent: 0, animated: false)
        }
        return birthLabel
    }

    private func buildGenderRow(below: UIView?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.l
        row.distribution = .fillEqually
        contentView.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        for (index, title) in ["女孩", "男孩"].enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appBody(15)
            button.tag = index == 0 ? 2 : 1
            button.layer.cornerRadius = Theme.Radius.input
            button.addTarget(self, action: #selector(didTapGender(_:)), for: .touchUpInside)
            updateGenderButton(button, selected: index == 0)
            row.addArrangedSubview(button)
            genderButtons.append(button)
        }
        return row
    }

    private func buildInterestRow(below: UIView?) -> UIView {
        let row = UIView()
        contentView.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let columns = 3
        let chipHeight: CGFloat = 34
        let chipGap: CGFloat = Theme.Spacing.m
        for (index, interest) in interests.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle(interest, for: .normal)
            chip.titleLabel?.font = .appLabel(12)
            chip.setTitleColor(Theme.Color.sub, for: .normal)
            chip.backgroundColor = Theme.Color.surfaceAlt
            chip.layer.cornerRadius = 17
            chip.tag = index
            chip.addTarget(self, action: #selector(didTapInterest(_:)), for: .touchUpInside)
            row.addSubview(chip)

            let column = index % columns
            let line = index / columns
            let chipWidth = CGFloat(interest.count * 13) + 32
            chip.snp.makeConstraints { make in
                make.width.equalTo(chipWidth)
                make.height.equalTo(chipHeight)
                make.leading.equalToSuperview().offset(CGFloat(column) * (chipWidth + chipGap))
                make.top.equalToSuperview().offset(CGFloat(line) * (chipHeight + chipGap))
                if index == interests.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
        return row
    }

    private func buildStudioRow(below: UIView?) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let title = UILabel()
        title.text = "绑定工作室学籍（可选）"
        title.font = .appBody(14)
        title.textColor = Theme.Color.ink
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        let status = UILabel()
        status.text = "暂不绑定"
        status.font = .appLabel(12)
        status.textColor = Theme.Color.brand
        card.addSubview(status)
        status.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(title)
        }

        let desc = UILabel()
        desc.text = "绑定学籍后，老师发布的课堂作品会自动归入孩子的成长档案。"
        desc.font = .appLabel(11)
        desc.textColor = Theme.Color.sub
        desc.numberOfLines = 2
        card.addSubview(desc)
        desc.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        return card
    }

    // MARK: - 交互

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapAvatar(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let index = view.tag
        selectedAvatar = avatarOptions[index]
        for (i, v) in avatarViews.enumerated() {
            v.layer.borderColor = (i == index ? Theme.Color.brand : UIColor.clear).cgColor
            v.backgroundColor = (i == index ? Theme.Color.brandSoft : Theme.Color.surfaceAlt)
        }
    }

    @objc private func didTapBirth() {
        view.endEditing(true)
        let alert = UIAlertController(title: "选择出生年份", message: nil, preferredStyle: .actionSheet)
        let picker = UIPickerView(frame: CGRect(x: 8, y: 8, width: 260, height: 160))
        picker.delegate = self
        picker.dataSource = self
        if let index = years.firstIndex(of: selectedYear) {
            picker.selectRow(index, inComponent: 0, animated: false)
        }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 276, height: 176))
        container.addSubview(picker)
        alert.view.addSubview(container)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self else { return }
            self.birthLabel.text = "\(self.selectedYear)年（\(self.age(for: self.selectedYear))）"
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = birthLabel
            popover.sourceRect = birthLabel.bounds
        }
        present(alert, animated: true)
    }

    @objc private func didTapGender(_ sender: UIButton) {
        selectedGender = sender.tag
        for button in genderButtons {
            updateGenderButton(button, selected: button.tag == selectedGender)
        }
    }

    @objc private func didTapInterest(_ sender: UIButton) {
        let interest = interests[sender.tag]
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
            sender.backgroundColor = Theme.Color.surfaceAlt
            sender.setTitleColor(Theme.Color.sub, for: .normal)
        } else {
            selectedInterests.insert(interest)
            sender.backgroundColor = Theme.Color.brandSoft
            sender.setTitleColor(Theme.Color.brand, for: .normal)
        }
    }

    private func updateGenderButton(_ button: UIButton, selected: Bool) {
        if selected {
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = Theme.Color.brand
        } else {
            button.setTitleColor(Theme.Color.sub, for: .normal)
            button.backgroundColor = Theme.Color.surface
            button.layer.borderWidth = 1
            button.layer.borderColor = Theme.Color.line.cgColor
        }
    }

    private func age(for year: Int) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return max(0, currentYear - year)
    }

    // MARK: - 保存

    @objc private func didTapSave() {
        view.endEditing(true)
        let nickname = nicknameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !nickname.isEmpty else {
            showToast("请填写孩子昵称")
            return
        }
        guard nickname.count <= 20 else {
            showToast("昵称最多 20 个字")
            return
        }

        showLoading("保存中...")
        ChildService.createChild(
            nickname: nickname,
            avatar: selectedAvatar,
            birthday: "\(selectedYear)-01-01",
            gender: selectedGender,
            interests: Array(selectedInterests)
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("添加成功")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.onSaved?()
                    self.dismiss(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message ?? "保存失败")
            }
        }
    }
}

// MARK: - TextField / Picker

extension AddChildViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension AddChildViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        years.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "\(years[row])年（\(age(for: years[row]))）"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedYear = years[row]
    }
}
