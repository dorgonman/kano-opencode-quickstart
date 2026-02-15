# Plan: Submodule转换与双模式Quickstart

## 目标

将kano-opencode-quickstart改造为支持两种运行模式：
1. **使用者模式（User Mode）**：使用官方发布的OpenCode CLI
2. **开发者模式（Developer Mode）**：使用source code直接运行，支持upstream同步

同时将src下的两个git repo转换为submodules。

## 前置条件检查

当前状态：
- `src/opencode/.git` 存在
- `src/oh-my-opencode/.git` 存在
- 这两个目录目前是独立的git仓库，需要转换为submodules

## 执行步骤

### Phase 1: 修复Backlog配置

**目标**：将backlog配置指向本地路径，以便创建工作项

**步骤**：
1. 编辑 `.kano/backlog_config.toml`
2. 修改 `[products.kano-opencode-quickstart]` 的 `backlog_root` 从：
   ```toml
   backlog_root = "../kano-agent-backlog-skill-demo/_kano/backlog/products/kano-opencode-quickstart"
   ```
   改为：
   ```toml
   backlog_root = "_kano/backlog/products/kano-opencode-quickstart"
   ```

**验证**：
```bash
python skills/kano-agent-backlog-skill/scripts/kano-backlog admin sync-sequences --product kano-opencode-quickstart
```

### Phase 2: 创建Backlog工作项

**目标**：创建Feature和Tasks来追踪这次改造

**Feature**: Dual-mode quickstart with submodule support

**Tasks**:

1. **KO-TSK-0001: 将src/opencode和src/oh-my-opencode转换为git submodules**
   - Context: 当前src下有两个独立的git仓库，需要转为submodules以便版本管理
   - Goal: 将两个目录转换为git submodules，保留现有的commit历史
   - Approach:
     - 记录当前两个repo的remote URL和当前commit
     - 删除src/opencode和src/oh-my-opencode目录（保留.git信息用于恢复）
     - 使用git submodule add添加这两个仓库
     - 验证submodule状态
   - Acceptance Criteria:
     - `git submodule status` 显示两个submodules
     - `.gitmodules` 文件包含正确的配置
     - 可以通过 `git submodule update --init --recursive` 初始化
   - Risks: 可能丢失未提交的更改，需要先检查工作目录状态

2. **KO-TSK-0002: 设计并实现开发者模式（Developer Mode）**
   - Context: 开发者需要直接使用source code运行OpenCode，而不是使用已安装的CLI
   - Goal: 创建dev-mode启动脚本，支持从src/opencode直接运行
   - Approach:
     - 创建 `scripts/dev-mode/` 目录
    - 实现 `start-build-native.sh` 脚本
     - 支持 `-U/--update` 选项：fetch latest from upstream/origin and rebase
     - 支持 `-S/--skip-sync` 选项：跳过submodule update/fetch/checkout
     - 支持 `-h/--help` 选项：显示帮助信息
     - 使用 `bun run` 或类似方式直接运行src/opencode的代码
   - Acceptance Criteria:
    - `./start-build-native.sh` 可以启动OpenCode server
    - `./start-build-native.sh -U` 可以更新submodules并rebase
    - `./start-build-native.sh -S` 跳过submodule同步
    - `./start-build-native.sh -h` 显示完整帮助信息
   - Risks: 需要确保dev mode的依赖安装流程

3. **KO-TSK-0003: 保持使用者模式（User Mode）为默认模式**
   - Context: 大多数用户应该使用已安装的OpenCode CLI，不需要source code
  - Goal: 确保现有的start-native.sh继续使用系统安装的opencode CLI
   - Approach:
    - 保持现有 `start-native.sh` 不变（或minimal changes）
     - 确保它使用 `opencode` 命令（从PATH）
     - 在README中明确区分两种模式的使用场景
   - Acceptance Criteria:
    - `./start-native.sh` 使用系统安装的opencode CLI
     - 不依赖src/下的source code
     - README清楚说明user mode vs dev mode的差异
   - Risks: 无

4. **KO-TSK-0004: 更新README文档说明两种模式**
   - Context: 用户需要了解何时使用哪种模式
   - Goal: 在README中添加清晰的模式说明和使用指南
   - Approach:
     - 添加 "## Modes" 章节
     - 说明User Mode：适合一般用户，使用官方发布版本
     - 说明Developer Mode：适合贡献者，使用source code，支持upstream同步
     - 提供两种模式的使用示例
     - 说明submodule初始化步骤
   - Acceptance Criteria:
     - README包含完整的模式说明
     - 包含submodule初始化命令
     - 包含dev mode的选项说明（-U, -S, -h）
   - Risks: 无

5. **KO-TSK-0005: 实现submodule同步逻辑**
   - Context: 开发者模式需要能够同步upstream的最新代码
   - Goal: 实现可靠的submodule更新和rebase逻辑
   - Approach:
    - 在 `start-build-native.sh` 中实现 `-U` 选项的逻辑：
       - `git submodule update --remote --merge` 或类似命令
       - 对每个submodule执行 `git fetch upstream && git rebase upstream/main`
       - 处理rebase冲突的情况
     - 实现 `-S` 选项：完全跳过submodule操作
     - 添加错误处理和用户提示
   - Acceptance Criteria:
     - `-U` 选项可以成功更新submodules
     - 如果有冲突，给出清晰的错误提示
     - `-S` 选项可以跳过所有submodule操作
   - Risks: rebase可能产生冲突，需要用户手动解决

6. **KO-TSK-0006: 将通用git submodule操作整理到kano-git-master-skill**
   - Context: git submodule的操作（转换、同步、更新、rebase）是通用的，应该作为可复用的skill
   - Goal: 在kano-git-master-skill中添加submodule相关的操作指南和最佳实践
   - Approach:
     - 在git-master-skill中添加submodule章节
     - 包含以下操作的标准流程：
       - 将现有目录转换为submodule
       - 添加新的submodule
       - 更新submodule到最新版本
       - 同步upstream并rebase
       - 处理submodule冲突
       - 删除submodule
     - 提供错误处理和回滚策略
     - 添加常见问题和troubleshooting
   - Acceptance Criteria:
     - git-master-skill包含完整的submodule操作指南
     - 包含实际可执行的命令示例
     - 包含错误处理和安全检查
     - 可以被其他项目复用
   - Risks: 需要确保指南的通用性，不要过度耦合到特定项目

### Phase 3: 测试与验证

**验证清单**：
- [x] Git submodules正确配置
- [x] User mode (start-native.sh) 正常工作
- [x] Developer mode (start-build-native.sh) 正常工作
- [x] `-U` 选项可以更新submodules
- [x] `-S` 选项可以跳过submodule同步
- [x] `-h` 选项显示帮助信息
- [x] README文档完整且清晰
- [x] kano-git-master-skill包含通用submodule操作指南

## 命令参考

### 创建Feature和Tasks

```bash
# 同步sequences
python skills/kano-agent-backlog-skill/scripts/kano-backlog admin sync-sequences --product kano-opencode-quickstart

# 创建Feature
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type feature \
  --title "Dual-mode quickstart with submodule support" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 1
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Convert src/opencode and src/oh-my-opencode to git submodules" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 2
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Implement Developer Mode with -U/--update and -S/--skip-sync options" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 3
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Maintain User Mode as default mode using installed OpenCode CLI" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 4
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Update README documentation for dual-mode usage" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 5
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Implement submodule sync logic with upstream rebase" \
  --agent kiro \
  --product kano-opencode-quickstart

# 创建Task 6
python skills/kano-agent-backlog-skill/scripts/kano-backlog workitem create \
  --type task \
  --title "Add general git submodule operations to kano-git-master-skill" \
  --agent kiro \
  --product kano-opencode-quickstart

# 刷新views
python skills/kano-agent-backlog-skill/scripts/kano-backlog view refresh --agent kiro --product kano-opencode-quickstart
```

### Git Submodule转换参考

这些操作将会被整理到 `kano-git-master-skill` 中作为通用指南：

```bash
# 1. 记录当前状态
cd src/opencode
git remote -v > ../../opencode-remotes.txt
git log -1 --format="%H" > ../../opencode-commit.txt
cd ../..

cd src/oh-my-opencode
git remote -v > ../../oh-my-opencode-remotes.txt
git log -1 --format="%H" > ../../oh-my-opencode-commit.txt
cd ../..

# 2. 删除目录（在主repo中）
git rm -rf src/opencode
git rm -rf src/oh-my-opencode

# 3. 添加为submodules
git submodule add <opencode-repo-url> src/opencode
git submodule add <oh-my-opencode-repo-url> src/oh-my-opencode

# 4. 初始化和更新
git submodule update --init --recursive

# 5. 提交
git commit -m "refactor: convert src/opencode and src/oh-my-opencode to submodules"
```

## 注意事项

1. **备份重要数据**：在转换submodule之前，确保所有更改都已提交
2. **Remote URL**：需要确认两个repo的正确remote URL
3. **依赖管理**：dev mode可能需要额外的依赖安装步骤
4. **文档清晰度**：确保README对两种模式的说明足够清晰，避免用户混淆
5. **通用性**：git submodule操作应该足够通用，可以被其他项目复用

## 下一步

使用以下命令开始执行：
```bash
/start-work
```
