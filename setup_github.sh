#!/usr/bin/env bash
# 一键配置 GitHub 仓库的协作规则（分支保护、合并策略、安全扫描）
#
# 前置：已装 gh CLI 并 gh auth login 完成，且当前目录已关联远端仓库
# 用法：bash setup_github.sh [审核人数，默认 1]
#
# 幂等：可重复执行，会覆盖同名 ruleset

set -euo pipefail

APPROVALS="${1:-1}"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "目标仓库：$REPO"
echo "要求审核人数：$APPROVALS"
echo

# ---------- 1. 合并策略 ----------
echo "[1/4] 配置合并策略：只允许 squash merge，合并后自动删分支"
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  --silent
echo "     完成"

# ---------- 2. 安全扫描 ----------
echo "[2/4] 开启密钥扫描与推送保护"
gh api -X PATCH "repos/$REPO" \
  --input - --silent <<'JSON' || echo "     跳过（私有仓库需 GitHub Advanced Security，或该功能不可用）"
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON
echo "     完成"

# ---------- 3. main 分支保护 ruleset ----------
echo "[3/4] 配置 main 分支保护规则"

# 已存在同名 ruleset 则先删除，保证幂等
EXISTING=$(gh api "repos/$REPO/rulesets" -q '.[] | select(.name=="main-protection") | .id' 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
  echo "     发现已有规则集（id=$EXISTING），先删除"
  gh api -X DELETE "repos/$REPO/rulesets/$EXISTING" --silent
fi

cat > /tmp/ruleset.json <<JSON
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $APPROVALS,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "Lint" },
          { "context": "Test (py3.11)" },
          { "context": "Test (py3.12)" }
        ]
      }
    }
  ],
  "bypass_actors": []
}
JSON

gh api -X POST "repos/$REPO/rulesets" --input /tmp/ruleset.json --silent
rm -f /tmp/ruleset.json
echo "     完成：禁止删除/强推，要求线性历史、PR 审核、CODEOWNERS 审核、对话解决、CI 通过"
echo "     bypass_actors 为空 —— 管理员同样受约束"

# ---------- 4. 仓库杂项 ----------
echo "[4/4] 关闭 wiki 与 projects（按需，可注释掉）"
gh api -X PATCH "repos/$REPO" \
  -F has_wiki=false \
  -F has_issues=true \
  --silent
echo "     完成"

echo
echo "全部配置完成。验证："
echo "  gh api repos/$REPO/rulesets -q '.[].name'"
echo
echo "还需手动做的两件事（GitHub 网页端）："
echo "  1. Settings → Collaborators and teams 添加成员，给 Write 权限"
echo "  2. 替换 .github/CODEOWNERS 里的 @OWNER_PLACEHOLDER 为真实账号"
