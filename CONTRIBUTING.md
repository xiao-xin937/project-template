# 协作规范

新成员请先完整读一遍这份文档，再开始第一个 PR。

## 一、本地环境准备

```bash
git clone https://github.com/<org>/<repo>.git
cd <repo>

# 建虚拟环境
python -m venv .venv
source .venv/Scripts/activate   # Windows Git Bash
# source .venv/bin/activate     # macOS / Linux

pip install -r requirements.txt -r requirements-dev.txt

# 装 pre-commit 钩子，把格式问题挡在提交之前
pre-commit install
```

配置 git 身份（用你的真实姓名和 GitHub 邮箱）：

```bash
git config user.name "你的名字"
git config user.email "you@example.com"
```

## 二、分支模型

采用 GitHub Flow：`main` 是唯一长期分支，永远保持可发布状态。所有改动走短生命周期特性分支 + Pull Request。

`main` 已开启分支保护，无法直接推送，必须通过 PR。

### 分支命名

```
feat/<简述>       新功能，如 feat/user-export
fix/<简述>        Bug 修复，如 fix/login-timeout
refactor/<简述>   重构
docs/<简述>       文档
test/<简述>       只加测试
chore/<简述>      构建、依赖、杂项
hotfix/<简述>     线上紧急修复
```

用小写和连字符，不要用中文和空格。

### 分支生命周期

控制在 1 到 3 天。分支活过一周，几乎必然陷入冲突泥潭。功能大就拆成多个 PR 分批合并，可以先合并没有对外暴露的底层部分。

## 三、日常开发循环

```bash
# 1. 同步主干
git checkout main
git pull

# 2. 开分支
git checkout -b feat/user-export

# 3. 开发并提交
git add -p                 # 逐块检查再暂存，避免误提交
git commit -m "feat(export): 支持用户数据导出为 xlsx"

# 4. 推送并开 PR（先开 Draft）
git push -u origin feat/user-export
gh pr create --fill --draft
```

写完、自测通过后，在 PR 页面点 **Ready for review**。

### 主干有更新时同步

```bash
git fetch origin
git rebase origin/main
# 有冲突就逐个解决，然后：
git add <解决后的文件>
git rebase --continue

git push --force-with-lease
```

**务必用 `--force-with-lease`，不要用 `--force`。** 前者在远端有别人的新提交时会拒绝推送，后者会直接覆盖掉同事的工作。

### 合并后清理

```bash
git checkout main
git pull
git branch -d feat/user-export
git remote prune origin
```

远端分支在合并时会自动删除，不用手动处理。

## 四、Commit 规范

采用 Conventional Commits：

```
<type>(<scope>): <描述>

[可选的正文]

[可选的脚注，如 BREAKING CHANGE: ...]
```

type 取值：`feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore` `revert`

示例：

```
feat(auth): 增加双因素登录
fix(parser): 修复送检单编号缺分隔符时漏解析
refactor(cost): 抽出检项名归一逻辑到单一实现
docs: 补充部署步骤
```

描述用中文没问题，type 和 scope 用英文。描述写「做了什么」，用陈述语气，末尾不加句号。

破坏性变更在脚注里写清迁移方式：

```
feat(api): 用户接口返回结构调整

BREAKING CHANGE: /api/users 的 name 字段拆分为 first_name 和 last_name，
调用方需同步更新。
```

合并到 main 时会 squash 成一个 commit，commit message 取 PR 标题和描述，所以**PR 标题也要符合上面的格式**。

## 五、Pull Request 规范

### 作者责任

- **PR 保持小**。改动控制在 400 行以内，超了就拆。大 PR 的审核质量会断崖下跌，这是团队协作里最容易被忽视的一条。
- **一个 PR 只做一件事**。重构和功能混在一起会让 reviewer 无法判断哪些改动是必要的。
- 描述里写清「为什么」和「影响范围」，代码本身能说明「做了什么」。
- 开 PR 前先自己看一遍 diff，把调试代码、注释掉的代码块、无关的格式改动清掉。
- CI 必须全绿。CI 红着就挂 Draft，不要占用 reviewer 时间。
- 有未解决的评论对话时不要合并。
- **谁开的 PR 谁合并**，作者最清楚是否还有后续动作要做。
- 不要自己 approve 自己的 PR。

### Reviewer 责任

- 首次响应 SLA：24 小时内。看不完就先说一句「今天下午看」，不要沉默。
- 评论用前缀区分严重度（Conventional Comments）：

  | 前缀 | 含义 |
  |---|---|
  | `blocking:` | 必须修改才能合并 |
  | `suggestion:` | 建议，作者可自行判断是否采纳 |
  | `nit:` | 吹毛求疵，不阻塞合并 |
  | `question:` | 单纯想弄清楚，不一定是问题 |
  | `praise:` | 写得好的地方，值得说出来 |

- 评论针对代码，不针对人。说「这里并发下会有竞态」而不是「你没考虑并发」。
- 只提 `blocking:` 时才用 Request changes，其余用 Comment 或 Approve。
- 审核要点：正确性、边界条件、错误处理、安全（注入、越权、密钥泄漏）、是否有对应测试、命名和可读性。性能只在有实际证据时提。

### 审核重点：安全

发现以下情况一律 `blocking:`

- 硬编码的密钥、token、密码、连接串
- 字符串拼接构造 SQL（应该用参数化查询）
- 未校验的用户输入直接进文件路径或 shell 命令
- 新增的网络端点没有认证或权限校验
- 依赖包名可疑（可能是仿冒包）或版本用了开放区间

## 六、测试要求

- 新功能必须带测试，Bug 修复必须带一个能复现该 Bug 的回归测试。
- 测试文件放 `tests/`，命名 `test_<模块名>.py`。
- 本地跑全量：`pytest`
- 跑单个文件：`pytest tests/test_parser.py -v`
- 看覆盖率：`pytest --cov --cov-report=term-missing`
- 测试不要依赖真实外部服务和真实业务数据，用 fixture 和 mock。

## 七、Issue 与任务跟踪

工作闭环：Issue → 分支 → PR → 合并自动关闭 Issue。

在 PR 描述里写 `Closes #12`，合并时 GitHub 会自动关闭对应 Issue。相关但不关闭的写 `Refs #12`。

开始动手前先有 Issue，哪怕只有一句话。这样进度可查、可分配、可回溯。

## 八、绝对不要做的事

- 不要 `git push --force` 到共享分支（包括别人也在用的特性分支）
- 不要把 `.env`、证书、私钥、真实业务数据提交进仓库
- 不要绕过分支保护直接推 `main`，管理员也不例外
- 不要用 `--no-verify` 跳过 pre-commit 钩子
- 不要在 PR 里夹带无关改动（尤其是全文件重新格式化，会把真实改动埋掉）
- 不要提交后不管 CI 就下班

## 九、密钥泄漏应急

如果不小心把密钥提交并推送了：

1. **立刻去服务方吊销这个密钥**，这是第一优先动作。改历史只是清理，泄漏已经发生了。
2. 通知仓库管理员。
3. 生成新密钥，存到 GitHub Secrets 或本地 `.env`。
4. 清理历史（需管理员配合，会重写历史，所有人要重新 clone）。

顺序不能颠倒。先吊销，再清理。
