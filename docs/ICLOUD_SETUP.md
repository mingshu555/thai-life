# iCloud / CloudKit 设置指南

## 概述

泰生活使用 CloudKit 同步个人学习数据（复习记录、收藏、会话草稿、设置）。
内容包（词库和音频）不通过 CloudKit 同步，仅随应用包发布。

## Apple Developer 前置条件

1. **Apple Developer Program**：需要付费会员资格（$99/年）。
2. **App ID**：在 [Apple Developer Portal](https://developer.apple.com) 创建 App ID `com.yaohuix.ThaiLife`。
3. **CloudKit 容器**：在同一页面启用 iCloud 和 CloudKit 服务，容器标识符为 `iCloud.com.yaohuix.ThaiLife`。
4. **推送通知**：CloudKit 同步依赖远程推送通知，确认为 App ID 启用。
5. **Xcode 签名**：在 Xcode 中选择正确的 Team 和 Provisioning Profile。

## Xcode 配置

`project.yml` 中已配置：
```yaml
entitlements:
  properties:
    com.apple.developer.icloud-container-identifiers:
      - iCloud.com.yaohuix.ThaiLife
    com.apple.developer.icloud-services:
      - CloudKit
    aps-environment: development
```

在 `AppContainer.swift` 中：
- 生产环境：`cloudKitDatabase: .automatic`
- 测试环境（内存）：`cloudKitDatabase: .none`

## 数据同步模型

### 不可变日志合并

1. **只写不可变日志**：每条复习记录写一次即不再修改。
2. **本地重放**：新设备收到日志后，将所有日志按 `reviewedAt` 排列，用 FSRS 重放计算当前卡片状态。
3. **不覆盖状态**：绝不直接同步卡片调度状态；状态是日志重放的函数。
4. **冲突处理**：同一 UUID 多条日志 → 保留一条（去重）。不同设备独立写日志 → 合并到总日志流。

### CloudKit 自动同步

- `NSPersistentCloudKitContainer` 自动处理增量同步。
- 无唯一约束、无必须关系 → 避免 CloudKit 冲突错误。
- 每个模型属性都有默认值 → schema 迁移安全。

## 部署步骤

### 开发阶段

1. Xcode → Signing & Capabilities → Team 选择你的开发者账号。
2. Xcode → Signing & Capabilities → iCloud → 勾选 CloudKit。
3. 在 Capabilities → Background Modes → 勾选 Remote Notifications。
4. 使用相同 Apple ID 登录两台测试设备。

### 生产部署

1. 在 App Store Connect 创建应用记录。
2. 将 CloudKit 容器部署到 Production 环境。
3. 将 `aps-environment` 改为 `production`。

## 两设备测试流程

1. 设备 A：安装应用，完成若干复习。
2. 等待 CloudKit 同步（通常 5-30 秒）。
3. 设备 B：安装应用，使用相同 Apple ID 登录。
4. 打开应用 → 应看到 A 的复习历史被合并。
5. 设备 B 下次到期卡片应与设备 A 重放后一致。

## 注意事项

- **仅在 Apple ID 登录后同步**：无 Apple ID 的设备数据仅本地保存。
- **内容包不覆盖**：内容更新只增加/迁移条目，不清除学习记录。
- **离线安全**：无网络时所有功能可用；上线后自动合并日志。
- **用户隐私**：不收集或传输用户身份信息；CloudKit 随 Apple ID 加密。
