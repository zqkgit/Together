import UIKit
import SnapKit

/// 家长发布动态
/// 流程：正文 + 图片 + 关联孩子(单选) + 可选关联课程 + 话题 + 谁可以看
/// 发布：POST /posts（createPost，不扣课时）
final class ParentPostCreateViewController: BasePostCreateViewController {

    // MARK: - 状态

    private var childList: [ChildItem] = []
    private var selectedChildId: String?
    private var selectedParentCourseIndex: Int?

    // MARK: - 数据

    override func loadFormData() {
        ChildService.fetchChildren { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.childList = list
                if self.selectedChildId == nil { self.selectedChildId = list.first?.child_id }
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
        loadTopics(reloadSection: 4)
    }

    // MARK: - TableView

    override func numberOfSections(in tableView: UITableView) -> Int { 6 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 3: return selectedParentCourseTitle != nil ? 1 : 0 // 关联课程：孩子无课程时隐藏
        default: return 1
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // 标题已移入卡片内，header 只作卡片间距；空 section（隐藏的卡片）不留间距
        if section == 0 { return 0 }
        return tableView.numberOfRows(inSection: section) == 0 ? 0 : 16
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextCell.reuseId, for: indexPath) as! TextCell
            cell.placeholder = "分享孩子的成长瞬间，老师和其他家长都能看到并点赞。"
            return card(cell)
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageGridCell.reuseId, for: indexPath) as! ImageGridCell
            cell.configure(images: images)
            cell.onAdd = { [weak self] in self?.pickImages() }
            cell.onDelete = { [weak self] index in
                guard let self, index < self.images.count else { return }
                self.images.remove(at: index)
                cell.configure(images: self.images)
                self.updateImageCellHeight()
            }
            return card(cell)
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "childTag")
            cell.selectionStyle = .none
            let selectedChildNames: Set<String> = Set(
                selectedChildId.flatMap { id in
                    childList.first(where: { $0.child_id == id }).map { [$0.nickname] }
                } ?? (childList.first.map { [$0.nickname] } ?? [])
            )
            _ = embedTagView(
                in: cell,
                title: "关联孩子",
                options: childList.map { $0.nickname },
                selected: selectedChildNames,
                multiple: false
            ) { [weak self] tags in
                guard let self else { return }
                if let name = tags.first, let child = self.childList.first(where: { $0.nickname == name }) {
                    self.selectedChildId = child.child_id
                    self.selectedParentCourseIndex = nil
                    self.tableView.reloadData()
                }
            }
            return card(cell)
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseId, for: indexPath) as! PickerCell
            cell.title = "关联课程"
            cell.detail = selectedParentCourseTitle ?? "不关联"
            return card(cell)
        case 4:
            return card(topicCell(tableView, indexPath: indexPath))
        case 5:
            return card(visibilityCell(tableView, indexPath: indexPath))
        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return UITableView.automaticDimension
        case 1:
            return 132 // 照片横向：100 高 + 上下间距 16×2
        case 2:
            return tagRowsHeight(childList.map { $0.nickname }) + Theme.Spacing.l * 2 + 40
        case 4:
            return tagRowsHeight(topics.map { "#\($0)" }) + Theme.Spacing.l * 2 + 40
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)
        if indexPath.section == 3 {
            presentParentCoursePicker()
        }
    }

    // MARK: - 校验与发布

    override func validateForm() -> Bool {
        guard selectedChildId != nil else {
            showToast("请选择关联孩子")
            return false
        }
        return true
    }

    override func publish(content: String, imageUrls: [String]) {
        PostService.createPost(
            content: content,
            images: imageUrls,
            childId: selectedChildId ?? "",
            courseId: selectedParentCourseId(),
            topic: topic,
            visibility: visibility
        ) { [weak self] postId, error in
            self?.handlePublishSuccess(postId: postId, error: error)
        }
    }

    // MARK: - 关联课程

    private var selectedParentCourseTitle: String? {
        guard let selectedChildId else { return nil }
        let child = childList.first(where: { $0.child_id == selectedChildId })
        let course = child?.balances?.first(where: { $0.status == 1 }) ?? child?.balances?.first
        return course?.course_title
    }

    private func presentParentCoursePicker() {
        guard let selectedChildId,
              let child = childList.first(where: { $0.child_id == selectedChildId }),
              let balances = child.balances, !balances.isEmpty else {
            showToast("该孩子暂无课程")
            return
        }
        let rows = balances.compactMap { $0.course_title }
        let picker = PickerSheetViewController(title: "关联课程", rows: rows + ["不关联"])
        picker.onConfirm = { [weak self] index in
            guard let self else { return }
            self.selectedParentCourseIndex = index < balances.count ? index : nil
            self.tableView.reloadData()
        }
        present(picker, animated: false)
    }

    private func selectedParentCourseId() -> String? {
        guard let selectedParentCourseIndex,
              let child = childList.first(where: { $0.child_id == selectedChildId }),
              let balances = child.balances, selectedParentCourseIndex < balances.count else { return nil }
        return balances[selectedParentCourseIndex].course_id
    }
}
