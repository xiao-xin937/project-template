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
if gh api -X PATCH "repos/$REPO" --input - --silent 2>/dev/null <<'JSON'
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON
then
  echo "     完成"
else
  echo "     跳过：该仓库不支持密钥扫描"
  echo "     （GitHub Free 的私有仓库不提供此功能；公开仓库免费，私有仓库需 GHAS）"
  echo "     替代方案：.pre-commit-config.yaml 里的 gitleaks 钩子在本地拦截，已配置"
fi

# ---------- 3. main 分支保护 ruleset ----------
echo "[3/4] 配置 main 分支保护规则"

# 前置检查：GitHub Free 的私有仓库不支持分支保护/rulesets，
# 直接调用会返回 403 且错误 JSON 会被误当成 ruleset id，所以先探测能力。
PROBE=$(gh api "repos/$REPO/rulesets" 2>&1) || PROBE_FAILED=1
if [ "${PROBE_FAILED:-0}" = "1" ]; then
  if echo "$PROBE" | grep -q "Upgrade to GitHub Pro"; then
    echo "     无法配置：GitHub Free 的私有仓库不支持分支保护"
    echo
    echo "     三条出路："
    echo "       1) 把仓库改为公开：gh repo edit $REPO --visibility public --accept-visibility-change-consequences"
    echo "          分支保护立即可用且免费。仅适用于不含敏感信息的仓库。"
    echo "       2) 升级 GitHub Pro（约 \$4/月），保持私有 + 完整分支保护。"
    echo "       3) 暂不配置服务端保护，依靠本地 pre-commit 钩子 + 团队约定。"
    echo "          注意：这只是软约束，任何人都能直接推 main。"
    echo
    echo "     其余配置（合并策略等）已生效。选定方案后重跑本脚本即可。"
    exit 2
  fi
  echo "     查询 rulesets 失败：$PROBE"
  exit 1
fi

# 已存在同名 ruleset 则先删除，保证幂等
EXISTING=$(printf '%s' "$PROBE" | jq -r '.[] | select(.name=="main-protection") | .id' 2>/dev/null || true)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
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
echo "全部配置完成。"
echo
echo "验证配置是否真正生效（强烈建议执行，配完不验证等于没配）："
echo "  gh api repos/$REPO/rulesets -q '.[] | .name + \" | \" + .enforcement'"
echo "  git push origin main    # 应被拒绝：Changes must be made through a pull request"
echo
echo "如果 CODEOWNERS 里还有 @OWNER_PLACEHOLDER，替换为真实账号："
echo "  sed -i \"s/@OWNER_PLACEHOLDER/@你的账号/g\" .github/CODEOWNERS"
echo
echo "邀请协作者（给 Write 权限，不要给 Admin）："
echo "  gh api -X PUT repos/$REPO/collaborators/<用户名> -f permission=push"
echo
echo "注意：要求 $APPROVALS 人审核且不能自我审核，意味着单人无法合并任何 PR。"
echo "团队成员到位前想自己走通流程，改用：bash setup_github.sh 0"
