import SwiftUI

// 今日详情 开关行/时间线/间隔标注/撤销条 作为PanelView扩展
extension PanelView {
    // 间隔标注 轨道在这里断成虚线 文字贴着断口 表达这段没喝水
    func gapMarker(_ minutes: Int) -> some View {
        let h = Int((Double(minutes) / 60).rounded())
        return HStack(spacing: 8) {
            Color.clear.frame(width: 32, height: 0)
            Rectangle()
                .stroke(Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(width: 1, height: 14)
            Text("隔了 \(h) 小时")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .padding(.vertical, 1)
    }

    // 今日详情 开关行 + 喝水时间线 时间正序
    var todayDetail: some View {
        let records = db.todayRecords()
        // 间隔标注条数 高度计算用
        let gapMarks = zip(records, records.dropFirst())
            .filter { $1.date.timeIntervalSince($0.date) >= 7200 }.count
        return VStack(spacing: 6) {
            Button {
                state.showDetail.toggle()
                // 布局要跳变 清掉悬停 免得水滴tooltip在光标下被扫出来
                state.setHover(nil)
                state.hoverRow = nil
            } label: {
                HStack(spacing: 6) {
                    Text("今日详情")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    // 分享按钮 紧跟标题后面 打开今日成就卡
                    shareBtn
                    Spacer()
                    // 胶囊小开关 朝下=展开 朝上=收起
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(state.showDetail ? 180 : 0))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.primary.opacity(0.07), in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // 不加动画 内容和窗口同一帧跳变 才不会有中间态空白
            if state.showDetail {
                if records.isEmpty {
                    Text("今天还没有记录")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                } else {
                    // 竖轨串起每一条 时间左 量右 悬停可删 可改ml
                    // 每行20pt(16内容+4上下距) 少时贴内容 多时3行封顶滚动
                    // showsIndicators:false 从AppKit层不创建指示器 gutter也不预留 scrollIndicators在预留gutter场景不生效
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { i, r in
                            // 隔太久插一条间隔标注
                            if i > 0 {
                                let gapMin = Int(r.date.timeIntervalSince(records[i - 1].date) / 60)
                                if gapMin >= 120 {
                                    gapMarker(gapMin)
                                }
                            }
                            timelineRow(r)
                        }
                        }
                    }
                    // 确定性高度 行20pt 标注16pt 超了封顶滚动
                    .frame(height: min(CGFloat(records.count) * 20 + CGFloat(gapMarks) * 16 + 2, 62))
                    .padding(.top, 2)
                }
            }
        }
    }

    // 时间线单行 时间/轨点/类型/量/删除
    func timelineRow(_ r: (id: Int64, date: Date, ml: Int, type: DrinkType)) -> some View {
        HStack(spacing: 8) {
            Text(Self.timeFormat.string(from: r.date))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .leading)
            ZStack {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 16)
            // 类型图标 水是蓝水滴 其他显示emoji 统一盒子保证对齐
            ZStack {
                if r.type == .water {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.accentColor.opacity(0.55))
                } else {
                    Text(r.type.emoji)
                        .font(.system(size: 9))
                }
            }
            .frame(width: 14, height: 14)
            Spacer()
            // 量 点击进编辑 回车保存 Esc取消
            if state.editingId == r.id {
                TextField("", text: Binding(
                    get: { state.editingText },
                    set: { state.editingText = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .frame(width: 42)
                .onSubmit { commitEdit() }
                .onExitCommand { state.editingId = nil }
            } else {
                Text("\(r.ml) ml")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.accentColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.editingId = r.id
                        state.editingText = "\(r.ml)"
                        state.editingOldML = r.ml
                    }
            }
            // 删除按钮 悬停该行才出现 占位不跳动
            ZStack {
                if state.hoverRow == r.id {
                    Button {
                        state.setUndo(.deleted(id: r.id, date: r.date, ml: r.ml, type: r.type),
                                      text: "已删除 \(r.ml) ml")
                        db.deleteDrink(id: r.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 14)
                            .background(.primary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 15)
        }
        .padding(.vertical, 2)
        .onHover { hovering in
            state.hoverRow = hovering ? r.id : (state.hoverRow == r.id ? nil : state.hoverRow)
        }
    }

    // 撤销条 最近一次删除/修改可反悔
    var undoBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(state.undoText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Button {
                performUndo()
            } label: {
                Text("撤销")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // 执行撤销
    func performUndo() {
        guard let u = state.undo else { return }
        switch u {
        case .added(let id):
            db.deleteDrink(id: id)
        case .deleted(_, let date, let ml, let type):
            db.restoreDrink(ts: date, ml: ml, type: type)
        case .edited(let id, let oldML):
            db.updateDrink(id: id, ml: oldML)
        }
        state.clearUndo()
    }

    // 保存编辑的ml 非法输入直接退出编辑
    func commitEdit() {
        defer {
            state.editingId = nil
            state.editingText = ""
        }
        guard let id = state.editingId, let ml = Int(state.editingText.trimmingCharacters(in: .whitespaces)) else { return }
        guard ml > 0, ml <= 5000 else { return }
        guard ml != state.editingOldML else { return }
        db.updateDrink(id: id, ml: ml)
        state.setUndo(.edited(id: id, oldML: state.editingOldML), text: "已改为 \(ml) ml")
    }
}
