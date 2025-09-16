# Auto-Commit Hook Bypass Strategy

## Problem Statement

Global git pre-commit hooks (especially security scanning hooks) can cause auto-commit systems to hang indefinitely. This is particularly problematic when hooks perform regex searches on large diffs or run extensive security scans.

### Specific Issue Identified

The security hook at `/home/ichardart/code/infra/security-tooling/git-hooks/pre-commit` contains:
```bash
git diff --cached -G"(password|secret|api.?key|token|credentials)" | grep -E "password|secret|api.?key|token|credentials"
```

This command can hang when processing large files or complex diffs, blocking automated commits.

## Solution: Smart Hook Management

The enhanced auto-commit script (`auto-commit-enhanced.sh`) implements a three-tier strategy:

### 1. Smart Mode (Default)
```bash
AUTO_COMMIT_SKIP_HOOKS=smart
```

**Behavior:**
- Detects if security hooks are present
- Tests hook responsiveness with a timeout (default 10 seconds)
- If hooks respond quickly: runs them normally
- If hooks hang/timeout: bypasses them with `--no-verify`
- Suggests manual security check after bypass

**Best for:** Most projects, especially those with security requirements

### 2. Always Skip Mode
```bash
AUTO_COMMIT_SKIP_HOOKS=always
```

**Behavior:**
- Always uses `--no-verify` flag for auto-commits
- Never runs pre-commit hooks for automated commits
- Manual commits still run hooks normally

**Best for:** Development environments where security scanning is done separately

### 3. Never Skip Mode
```bash
AUTO_COMMIT_SKIP_HOOKS=never
```

**Behavior:**
- Always runs pre-commit hooks
- May cause hanging if hooks are slow
- Maintains full security compliance

**Best for:** Production or high-security environments where all commits must be scanned

## Implementation Details

### Hook Detection
```bash
check_for_security_hooks() {
    local hooks_path=$(git config --get core.hooksPath)
    if grep -q "password\|secret\|api.*key" "$hooks_path/pre-commit"; then
        return 0  # Security hooks detected
    fi
}
```

### Responsiveness Testing
```bash
test_hook_responsiveness() {
    # Create test commit with timeout
    timeout "$HOOK_TIMEOUT" git commit --dry-run -m "Test"
    # Returns 0 if responsive, 1 if timeout
}
```

### Smart Commit Logic
```bash
if hooks_are_slow; then
    git commit --no-verify -m "$msg"
    echo "💡 Run manual security check"
else
    git commit -m "$msg"  # Normal commit with hooks
fi
```

## Deployment Guide

### For MQ Studio Project

1. **Deploy with automatic detection:**
```bash
cd ~/active-projects/docker-dev-environments
./scripts/deploy-auto-commit.sh ~/code/clients/website-mq-studio
```

2. **Test hooks before starting:**
```bash
cd ~/code/clients/website-mq-studio
./scripts/auto-commit.sh test-hooks
```

3. **Start with appropriate mode:**
```bash
# Smart mode (recommended)
./scripts/auto-commit.sh watch

# Or force skip mode if hooks are problematic
AUTO_COMMIT_SKIP_HOOKS=always ./scripts/auto-commit.sh watch
```

### Manual Configuration

Create `.auto-commit-config` in project root:
```bash
# Smart hook handling
AUTO_COMMIT_SKIP_HOOKS=smart
AUTO_COMMIT_HOOK_TIMEOUT=10

# Other settings
AUTO_COMMIT_INTERVAL=300
AUTO_PUSH=false
```

## Security Considerations

### When Hooks Are Bypassed

If auto-commit bypasses security hooks, manually check for secrets:

```bash
# Check last commit for potential secrets
git diff HEAD~1 | grep -E "password|secret|api.*key|token|credentials"

# Use dedicated tools
git secrets --scan
gitleaks detect --verbose

# Review before pushing
git log --oneline -5  # Review recent commits
```

### Best Practices

1. **Development:** Use `smart` or `always` skip mode for convenience
2. **Staging:** Use `smart` mode to balance security and productivity
3. **Production:** Consider `never` skip mode or disable auto-commit
4. **CI/CD:** Run comprehensive security scans in pipeline

## Troubleshooting

### Issue: Auto-commit still hanging

**Solution:**
```bash
# Force skip mode
AUTO_COMMIT_SKIP_HOOKS=always ./scripts/auto-commit.sh watch

# Or reduce timeout
AUTO_COMMIT_HOOK_TIMEOUT=5 ./scripts/auto-commit.sh watch
```

### Issue: Security team requires all commits scanned

**Solution:**
```bash
# Use never skip mode
AUTO_COMMIT_SKIP_HOOKS=never ./scripts/auto-commit.sh watch

# Or disable auto-commit and use manual commits
./scripts/auto-commit.sh stop
```

### Issue: Want to test if hooks work

**Solution:**
```bash
# Test hook responsiveness
./scripts/auto-commit.sh test-hooks

# Dry run with hooks
git commit --dry-run -m "Test"
```

## Configuration Matrix

| Environment | Skip Mode | Hook Timeout | Auto-Push | Rationale |
|------------|-----------|--------------|-----------|-----------|
| Local Dev | `smart` | 10s | false | Balance convenience & security |
| Feature Branch | `always` | - | false | Speed over security scanning |
| Main Branch | `never` | 30s | false | Full security compliance |
| CI/CD | N/A | - | - | Don't use auto-commit in CI |
| Client Project | `smart` | 10s | false | Detect and adapt to their hooks |

## Summary

The enhanced auto-commit system provides flexible hook management that:

1. **Prevents hanging** from slow security hooks
2. **Maintains security** when hooks are fast
3. **Adapts automatically** to different environments
4. **Provides transparency** about when hooks are skipped
5. **Suggests manual checks** when automated scanning is bypassed

This ensures auto-commit remains functional even in environments with complex pre-commit hooks while maintaining security awareness.