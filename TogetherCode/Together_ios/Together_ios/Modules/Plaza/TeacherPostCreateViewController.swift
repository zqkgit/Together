import UIKit
import SnapKit

/// 老师发布动态
/// 流程：正文 + 图片 + 课程·班级(选班后带学生多选) + 同步消课(开关+课次) + 话题 + 谁可以看
/// 发布：POST /teacher/posts（createTeacherPost；consume=true 才扣课时）
/// 业务约束：选择学生=关联家长可见/推送；同步消课=独立扣课时，两者解耦
final class TeacherPostCreateViewController: BasePostCreateViewController {

    // MARK: - 状态

    private var teacherClasses: [TeacherClassItem] = []
    private var classStudents: [TeacherStudentItem] = []
    private var selectedClass: TeacherClassItem?
    private var selectedStudentIds = Set<String>()
    private var consumeEnabled = false

    // MARK: - 数据

    override func loadFormData() {
        PostService.fetchTeacherClasses { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.teacherClasses = list
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
        loadTopics(reloadSection: 4)
    }

    private func loadClassStudents(classId: String) {
        PostService.fetchTeacherClassStudents(classId: classId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.classStudents = list
                self.selectedStudentIds.removeAll()
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    // MARK: - TableView

    override func numberOfSections(in tableView: UITableView) -> Int { 6 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 2, 3: return teacherClasses.isEmpty ? 0 : 1 // 课程·班级/消课卡片：无班级时用不到
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
            cell.placeholder = "记录这节课的精彩瞬间，分享给家长…"
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
            let cell = tableView.dequeueReusableCell(withIdentifier: TeacherClassCell.reuseId, for: indexPath) as! TeacherClassCell
            cell.configure(
                classDetail: selectedClass?.displayName ?? "请选择",
                students: classStudents.map { $0.nickname },
                selected: Set(classStudents.filter { selectedStudentIds.contains($0.child_id) }.map { $0.nickname }),
                hasClass: selectedClass != nil
            )
            cell.onTapClass = { [weak self] in self?.presentClassPicker() }
            cell.onStudentsChanged = { [weak self] tags in
                guard let self else { return }
                self.selectedStudentIds = Set(self.classStudents.filter { tags.contains($0.nickname) }.map { $0.child_id })
            }
            return card(cell)
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: ConsumeCell.reuseId, for: indexPath) as! ConsumeCell
            cell.configure(switchValue: consumeEnabled)
            cell.onSwitch = { [weak self] on in
                guard let self else { return }
                self.consumeEnabled = on
                self.tableView.reloadData()
            }
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
            // 未选班级：只显示课程·班级行 48；选了班级：+ 分割线 + 学生区
            guard selectedClass != nil else { return 48 }
            return 48 + 0.5 + 12 + 18 + 8 + tagRowsHeight(classStudents.map { $0.nickname }) + Theme.Spacing.l
        case 3:
            // 消课开关：标题 20 + 副标题 17 + 上下内边距 16×2
            return 70
        case 4:
            return tagRowsHeight(topics.map { "#\($0)" }) + Theme.Spacing.l * 2 + 40
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)
        if indexPath.section == 2 {
            presentClassPicker()
        }
    }

    // MARK: - 校验与发布

    override func validateForm() -> Bool {
        if consumeEnabled {
            guard selectedClass != nil else { showToast("请先选择课程班级"); return false }
            guard !selectedStudentIds.isEmpty else { showToast("请选择上课学生"); return false }
        }
        return true
    }

    override func publish(content: String, imageUrls: [String]) {
        // 关联学生（家长可见/推送）与消课分离：选学生即关联；consume=true 才扣课时
        // 消课课次由后端按班级自动匹配（今天优先，无则最近一次）
        let students: [[String: Any]] = selectedStudentIds.map { ["child_id": $0, "count": 1] }
        PostService.createTeacherPost(
            content: content,
            images: imageUrls,
            courseId: selectedClass?.course?.course_id,
            classId: selectedClass?.class_id,
            scheduleId: nil,
            students: students,
            consume: consumeEnabled,
            topic: topic,
            visibility: visibility
        ) { [weak self] postId, error in
            self?.handlePublishSuccess(postId: postId, error: error)
        }
    }

    // MARK: - 选择器

    private func presentClassPicker() {
        guard !teacherClasses.isEmpty else {
            showToast("暂无班级")
            return
        }
        let picker = PickerSheetViewController(title: "选择课程班级", rows: teacherClasses.map { $0.displayName })
        picker.onConfirm = { [weak self] index in
            guard let self, index < self.teacherClasses.count else { return }
            self.selectedClass = self.teacherClasses[index]
            self.selectedStudentIds.removeAll()
            self.classStudents = []
            self.loadClassStudents(classId: self.teacherClasses[index].class_id)
        }
        present(picker, animated: false)
    }
}
