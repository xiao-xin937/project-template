# Project Template

团队协作开发模板。包含分支保护、Code Review、CI、Issue/PR 模板等一整套 GitHub 多人协作配置，新项目直接套用。

## 快速开始

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
pip install -r requirements.txt -r requirements-dev.txt
pre-commit install
pytest
```

## 目录结构

```
.github/
  workflows/ci.yml          CI：lint + 多版本 pytest
  ISSUE_TEMPLATE/           Bug / 功能需求表单
  CODEOWNERS                各路径默认审核人（需替换占位账号）
  pull_request_template.md  PR 模板
src/                        源码
tests/                      测试
CONTRIBUTING.md             协作规范，新人必读
pyproject.toml              ruff / pytest / coverage 配置
.pre-commit-config.yaml     提交前钩子
setup_github.sh             一键配置远端仓库保护规则
```

## 协作流程

采用 GitHub Flow，`main` 是唯一长期分支：

```
main ──┬─────────────────────────┬──> 始终可发布
       │                         │
       └── feat/xxx ──PR──review──┘
```

1. 从 `main` 切特性分支
2. 提交，推送，开 PR
3. CI 通过 + 至少 1 人 approve
4. Squash merge 回 `main`，分支自动删除

完整规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 把这个模板用到新项目

```bash
# 方式一：GitHub 上把本仓库设为 Template repository，然后
gh repo create myorg/newproject --private --template myorg/project-template

# 方式二：复制配置文件
cp -r project-template/.github project-template/CONTRIBUTING.md \
      project-template/.pre-commit-config.yaml newproject/
```

之后记得：

- 替换 `.github/CODEOWNERS` 里的 `@OWNER_PLACEHOLDER`
- 跑 `bash setup_github.sh` 配置分支保护
- 改 `pyproject.toml` 里的项目名

## 发布

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 --generate-notes
```

<!-- 分支保护验证，合并后可删除此行 -->
