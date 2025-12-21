# BearRouter 设计文档 & 生成提示词（低学习成本版）

目标：输出一个“拿来就用”的 SwiftUI 导航库（BearRouterCore + BearRouter + Testing），默认强类型、安全，同时兼顾旧项目迁移的低心智负担。

---

## 设计原则（面向使用者友好）
- **3 步上手**：定义 Route → 注册 Destination → 选择 Host（Stack/Tab/Split）即可。Intent 层可选。
- **强类型 & 并发安全**：`Hashable & Sendable` 路由，Guard/Logger/Snapshot 泛型化，主线程可观测。
- **零样板**：常用操作提供便捷 API（push/pop/sheet/fullScreen、selectTab/setSplitSelection 适配器、withNavigationPath 包装）。
- **兼容迁移**：可选 sceneID、字符串 tab/selection 适配层（RawRepresentable(String) 或自定义解析器 + 兼容动作翻译），让旧项目平滑过渡。
- **无黑盒**：核心状态与 reducer 纯 Swift，可测试、可持久化。

## 模块拆分（SPM Targets）
1) **B e a r R ou te rCore**（纯 Swift）
   - 模型：`NavigationState`、`TabState`、`SplitState`
   - 动作：`NavigationAction<Route>` + 兼容层（tab/split 选择翻译）
   - 状态机：`Navigator<Route>`、`TabNavigator<TabID, Route>`、`SplitNavigator<Selection, Route>`
   - 守卫：`NavigationGuard<Route>` + `GuardContext<Route>`
   - 日志：`NavigationLogger<Route>`（`ConsoleLogger`/`NoOpLogger`）
   - 快照 & 持久化：`NavigationSnapshot`、`TabSnapshot`、`SplitSnapshot`、`NavigationPersistence`
   - 可选：sceneID 支持、字符串兼容解析（RawRepresentable/String 解析器）
2) **BearRouter**（SwiftUI 容器）
   - 宿主：`StackNavigationHost`、`TabNavigationHost`、`SplitNavigationHost`
   - 注册表：`DestinationRegistry<Route>`（Route → View），含 fallback
   - 意图：`IntentRouterProtocol`、`BearRouterigator/TabBearRouterigator/SplitBearRouterigator`、`IntentDispatcher`/`AnyIntentDispatcher`
   - **NavigationPath 适配层**：`NavigationPathAdapter<Route>`、`PathStackNavigationHost`、`withNavigationPath`
   - 便捷：同步/异步 Intent 发送（sync 仅测试/调试）
3) **BearRouterTesting**（可选）
   - Mock Guard、内存持久化、便捷断言

## 核心模型/动作
- `NavigationState<Route>`：`path` + `sheet` + `fullScreen`
- `TabState<TabID, Route>`：`selectedTab` + `perTab`
- `SplitState<Selection, Route>`：`selection` + `detail`
- `NavigationAction<Route>`：push/pop/popToRoot/replaceStack/present&dismiss sheet/fullScreen/dismissAll/batch
- 兼容动作翻译：selectTab / setSplitSelection（转换为 Tab/Split 专属 Action）

## 状态机（含兼容/便捷）
- `Navigator<Route>`：单栈，带 Guard + Logger；`snapshot/restore`（Codable）
- `TabNavigator<TabID, Route>`：每 Tab 独立状态；便捷 `selectTab(_:)`，字符串选择可通过 RawRepresentable(String) 或自定义解析器；snapshot/restore
- `SplitNavigator<Selection, Route>`：sidebar selection + detail 栈；字符串 selection 可通过 RawRepresentable(String) 或自定义解析器；snapshot/restore

## Guard & Logger
- `NavigationGuard<Route>`：`evaluate(actionDescriptions: [String], context: GuardContext<Route>) async -> GuardDecision<Route>`
- `GuardDecision<Route>`：allow / deny(reason) / redirect(path, replay)
- `NavigationLogger<Route>`：`ConsoleLogger` / `NoOpLogger`，支持 sceneID 透传

## SwiftUI 宿主
- `StackNavigationHost`：`NavigationStack` + `.navigationDestination`
- `TabNavigationHost` + `NavigableTab`：每 Tab 独立 `NavigationStack`
- `SplitNavigationHost`：`NavigationSplitView` + detail 栈（仅 iOS/macOS/visionOS）
- Modal：`sheet(item:)`（全平台）、`fullScreenCover`（iOS 等）

## NavigationPath 适配（优先无反射）
- `NavigationPathAdapter<Route>`：由调用方提供 encode/decode（默认 AnyHashable），优先使用稳定提取（不依赖反射）；必要时可自定义替代方案；可选 drop 回调。
- 绑定：
  - 单栈：`adapter.binding(for: navigator)`
  - Tab：`adapter.binding(for: tabNavigator, tabID:)`
  - Split detail：`adapter.detailBinding(for:)`
- `PathStackNavigationHost` / `withNavigationPath`：内部用 `NavigationPath`，外层保持强类型 API

## Intent 层
- `IntentRouterProtocol`: `route(_ intent) -> [NavigationAction<Route>]`（@Sendable）
- `BearRouterigator/TabBearRouterigator/SplitBearRouterigator`: intent → actions → navigator，支持 async / sync（sync 仅测试）
- 环境注入：`.intentDispatcher(...)` + `EnvironmentValues.intentDispatcher`

## 快速骨架（便捷 & 兼容）
```swift
// 1) 定义路由
enum Route: Hashable, Sendable, Codable { case home, detail(id: Int) }

// 2) 注册目的地
let registry = DestinationRegistry<Route> { _ in AnyView(EmptyView()) }
registry.register(Route.self) { route in
    switch route {
    case .home: HomeView()
    case .detail(let id): DetailView(id: id)
    }
}

// 3) 搭宿主
let navigator = Navigator<Route>()
StackNavigationHost(navigator: navigator, registry: registry) { HomeView() }

// Intent → Action
struct AppRouter: IntentRouterProtocol {
    func route(_ intent: AppIntent) -> [NavigationAction<Route>] { /* ... */ }
}
let BearRouter = BearRouterigator(navigator: navigator, router: AnyIntentRouter(AppRouter()))
let dispatcher = BearRouter.makeDispatcher() // async
// Tab 选择兼容（旧式 selectTab）
// TabBearRouterigator 内部将 selectTab 动作翻译成 TabNavigationAction
```

## 复刻/实现步骤（生产向）
1) 建 SPM 包（BearRouterCore/SwiftUI/Testing）。
2) Core：状态/动作/Guard/Logger/Snapshot/Persistence + Navigator/Tab/Split，加入 sceneID 透传与兼容 tab/selection 适配。
3) SwiftUI：Registry + Hosts（Stack/Tab/Split）+ Intent 层（async/sync）+ NavigationPathAdapter（无反射）。
4) 文档与示例：最小 3 步用法 + 迁移指南（旧版 selectTab → TabActionTranslator 等）。
5) 可选示例：Tab + Deep Link + Restore。
6) 可选 Testing 工具。

## Codex 提示词（新版，强调低心智负担）
```
你是资深 Swift/SwiftUI 库作者，要从零实现 SPM 包 “BearRouterKit”，要求：
- 3 步可用：定义 Route → 注册 Destination → 选宿主（Stack/Tab/Split）。Intent 层可选。
- 强类型 & Sendable：Route/TabID/Selection 皆 Hashable & Sendable，可 Codable 快照；Guard/Logger/Snapshot 泛型化。
- 兼容迁移：可选 sceneID；字符串 tab/selection 通过 RawRepresentable(String) 或自定义解析器；提供动作翻译器以兼容旧式 selectTab/setSplitSelection。
- NavigationAction：push/pop/popToRoot/replaceStack/present&dismiss sheet/fullScreen/dismissAll/batch；selectTab/setSplitSelection 通过适配层翻译为 Tab/Split 专属 Action。
- 状态机：Navigator / TabNavigator / SplitNavigator（带 Guard/Logger，支持 snapshot/restore）。
- SwiftUI：StackNavigationHost/TabNavigationHost/SplitNavigationHost + DestinationRegistry（含 fallback）；Modal 支持 sheet 和（iOS）fullScreenCover。
- NavigationPathAdapter：encode/decode 基于 AnyHashable，无反射；PathStackNavigationHost/withNavigationPath 包装。
- Intent 层：IntentRouterProtocol（@Sendable）、BearRouterigator/TabBearRouterigator/SplitBearRouterigator，支持 async/sync 发送；Environment 注入 dispatcher。
- Targets：BearRouterCore、BearRouter、BearRouterTesting（Mock Guard、内存持久化）；平台 iOS18+/macOS15+/tvOS18+/watchOS11+/visionOS2+。
- 产出完整源码 + README，全部 ASCII。
```

## 使用建议（简版）
- 优先用强类型枚举路由；旧项目需要字符串 ID 时开启兼容协议/翻译器。
- Registry 设置 fallback（调试可 fatalError），避免漏注册空白页。
- 持久化仅存轻量 ID，避免把大模型塞进 Route。
- Guard 用于登录/权限等前置校验，必要时用 redirect+replay；Logger 可换成你自己的埋点。
