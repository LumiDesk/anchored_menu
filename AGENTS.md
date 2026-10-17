# Anchored Menu Agent 开发指南

本文件是仓库内 Agent 与维护者的执行规范，记录当前架构边界、质量门禁和发布规则。

## 项目定位

`anchored_menu` 是发布到 pub.dev 的独立 Flutter Widget 包，提供贴近触发器显示、支持递归卡片式子菜单的锚点弹出菜单。

- 仓库：`LumiDesk/anchored_menu`
- 包名：`anchored_menu`
- 许可证：BSD 3-Clause
- CI 固定工具链：Flutter 3.47.2 / Dart 3.13.2
- 运行时依赖：仅 Flutter SDK

这个包必须保持可脱离 Veri Fin 独立使用。不要在包内引入业务模型、账目概念、Veri Fin 设计令牌、应用本地化文案或应用状态管理。

与维护者沟通时使用中文；代码、API 名称、提交信息和包文档使用英文。

## 当前架构

| 路径 | 职责 |
| --- | --- |
| `lib/anchored_menu.dart` | 稳定的公开 barrel，消费者只需导入这个文件 |
| `lib/src/anchored_menu_anchor.dart` | 公开触发器组件与受控单选适配层 |
| `lib/src/anchored_menu_entry.dart` | 公开菜单条目与数据模型 |
| `lib/src/anchored_menu_theme.dart` | 公开 `ThemeExtension` 与解析后的主题值 |
| `lib/src/anchored_menu_route.dart` | 内部弹层路由、定位、动画、焦点与绘制 |
| `example/` | 通过 path dependency 使用本包的可运行 Android/Web 示例 |
| `test/` | Widget 测试与发布脚本单元测试 |
| `scripts/publish.dart` | 维护者发布辅助脚本 |
| `doc/screenshots/` | README 与 pub.dev 使用的截图 |

`AnchoredMenuRoute` 和 `ResolvedAnchoredMenuTheme` 位于 `lib/src`，不从公开 barrel 导出。路由和渲染实现应保持私有；如果其他文件需要复用，优先抽到明确的内部模块，不要直接导出实现细节。

## 公开 API 规则

当前公开入口包括：

- `AnchoredMenuAnchor`
- `AnchoredMenuButton`
- `AnchoredMenuChoice<T>`
- `AnchoredMenuEntry`
- `AnchoredMenuItem`
- `AnchoredMenuDivider`
- `AnchoredMenuAnchorBuilder`
- `AnchoredMenuThemeData`

遵守以下规则：

- 使用中性的产品命名，不添加 `Veri` 或 Veri Fin 前缀。
- Widget API 保持受控：选中值、禁用状态和当前值都由调用方提供。
- 每个菜单项必须有稳定且唯一的 `id`，不能用本地化标题或列表索引生成。
- `keyPrefix` 必须可配置。默认 key 使用 `anchored_menu_*`；现有消费者可传入自己的前缀以保持集成测试 key 不变。
- 不直接访问应用 Controller、持久化、Provider 或全局状态。
- 公开标识符必须有有效的 Dart 文档注释。
- 优先增加参数扩展已有能力，不复制同构 Widget。

1.0 之前可以随 minor 版本发布破坏性 API 调整，但必须在 `CHANGELOG.md` 中明确说明。

## 行为不变量

除非需求明确要求修改，否则必须保留以下行为：

- 菜单相对触发器定位，并始终限制在可视区域内。
- 下方空间足够时向下展开，否则向上展开。
- 进入多级菜单时保留完整的祖先卡片栈。
- 子菜单从被激活的行原位展开，内容保持连续。
- 点击菜单外部关闭整棵菜单。
- Android/系统返回先退一级子菜单，根层再关闭整个菜单。
- 上下方向键在可用菜单项之间移动高亮。
- `Enter`、小键盘 `Enter` 和空格激活当前高亮项。
- 水平方向键根据 LTR/RTL 阅读方向工作。
- `Escape` 和水平返回操作一次只退一级。
- 键盘导航跳过禁用项。
- 菜单容器和选中项保持正确的读屏语义。
- 文本测量必须使用当前 `TextDirection` 和 `TextScaler`。
- 系统开启减少动态效果时尊重 `MediaQuery.disableAnimationsOf(context)`。

当前动效时长为：根菜单 220ms、子菜单前进 280ms、子菜单返回 260ms。除非需求明确，不得顺手修改。

## 主题与样式

`AnchoredMenuThemeData` 是包自身的样式边界，可覆盖：

- 表面色和描边色
- 前景色和选中色
- 面板圆角和条目圆角
- 标题和副标题样式
- 最小菜单宽度

未指定的值从外围 Material 主题解析。不要导入应用主题文件，也不要硬编码消费者品牌色。

菜单表面必须保持不透明。不要引入背景模糊、折射、着色器滤镜或装饰性渐变。

## 代码质量

- 遵循 Dart 默认格式，使用两个空格缩进。
- 文件使用 `snake_case.dart`，公开类型使用 `UpperCamelCase`。
- 优先使用小型内部辅助逻辑，避免演化成参数过多的配置对象。
- Flutter 已提供的行为不要额外引入依赖。
- 新增依赖必须说明维护成本、包体积、许可证和跨平台影响。
- 不使用 `print` 输出库日志。
- 除非明确扩大包的范围，不新增平台插件。
- 行为变化时同步更新公开 API 文档。

## 测试

每项行为变化都必须有针对性 Widget 或单元测试。

提交前执行：

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

随后在 `example/` 目录执行：

```powershell
flutter analyze
flutter test
```

测试应覆盖适用的场景：

- 根菜单定位与屏幕边缘避让
- 递归子菜单导航
- 选中、禁用、分割线、图标和副标题状态
- 点击外部关闭与系统返回
- 键盘焦点与激活
- RTL 布局和方向
- 窄屏、长文案和大字号
- 自定义宽度与 key 前缀
- 主题扩展的回退与覆盖
- example 集成

不要用 golden 测试替代交互测试。可以增加 golden 做视觉回归，但仍需保留行为断言。

## 发布包卫生

发布前必须先检查：

```powershell
dart pub publish --dry-run
```

完整确认待发布文件列表。

`.pubignore` 会覆盖 `.gitignore` 的发布忽略规则。修改 `.pubignore` 时必须确认以下本地构建/缓存内容仍被排除：

- `/build/`
- `/coverage/`
- `/doc/api/`
- `/*.iml`
- `scripts/`
- `test/scripts_publish_test.dart`

发布校验必须为 `0 warnings`。不要使用 `--skip-validation`，也不要忽略无关警告。

README 和 `pubspec.yaml` 引用的截图路径必须真实存在，并被包含在发布归档中。

## 发布流程

`CHANGELOG.md` 必须包含 `## [Unreleased]` 段落和发布说明。发布脚本会把其中的说明提升为带日期的正式版本。

先预览：

```powershell
dart run scripts/publish.dart patch --dry-run
```

正式发布命令：

```powershell
dart run scripts/publish.dart patch
dart run scripts/publish.dart minor
dart run scripts/publish.dart major
dart run scripts/publish.dart 1.2.3
```

脚本会依次：

1. 要求 `main` 分支工作树干净，且不落后 `origin/main`。
2. 校验本机 Flutter 与 CI 固定版本一致。
3. 更新 `pubspec.yaml` 和 `CHANGELOG.md`。
4. 执行格式化、依赖安装、包与 example 的静态分析和测试。
5. 校验发布包内容。
6. 创建 `chore: release vX.Y.Z` 提交。
7. 创建并推送 annotated `vX.Y.Z` 标签。
8. 等待 GitHub Actions 发布 workflow。

未经维护者明确授权，不要运行正式发布脚本、推送发布标签或直接执行 `dart pub publish`。

pub.dev 已发布版本不可覆盖。发布标签不得复用、移动或删除；仓库 ruleset 已保护 `v*` 标签不被更新和删除。

## GitHub 与贡献

- 外部 PR 创建已通过 `pull_request_creation_policy: collaborators_only` 关闭。
- Issue 保持开放，用于接收反馈。
- 未经维护者明确决定，不得重新开放外部 PR。
- 接受的改动由维护者直接实施。
- 未经要求不要推送提交。
- 使用简短明确的提交信息，如 `feat: add ...`、`fix: ...`、`chore: ...`；不要添加 AI 或 Codex 署名。

## CI 与发布

- `.github/workflows/ci.yml` 在 `main` 和 PR 上执行格式检查、静态分析、包测试、example 测试和发布 dry-run。
- `.github/workflows/publish.yml` 只在推送 `vX.Y.Z` 标签时运行。
- 发布使用 pub.dev OIDC 和官方 `dart-lang/setup-dart/.github/workflows/publish.yml@v1` reusable workflow。
- pub.dev 的 tag pattern 是 `v{{version}}`，`pubspec.yaml` 版本必须与标签完全一致。
- 不要把长期有效的 pub.dev 凭据加入 GitHub Secrets。

## 文档与完成标准

- `README.md` 是公开包页面，必须保持安装、用法、主题、键盘行为、截图和许可证信息准确。
- `CHANGELOG.md` 记录所有已发布变化，使用面向用户的措辞。
- 不在仓库中添加计划、过程记录或评审 transcript。
- 实现与文档冲突时，先以源码、测试、workflow 和发布脚本为准，再同步修正文档。

汇报完成前确认：

- 改动严格落在需求范围内。
- 工作树没有误生成的构建文件。
- 已运行适用的 format、analyze、包测试和 example 测试。
- 修改包内容、元数据或发布行为时，已运行 `dart pub publish --dry-run`。
- 汇报中列出已执行命令、结果、创建/更新的提交，以及明确未执行的验证。
