# Claude Code Hook: Block Destructive Commands
# This script runs as a PreToolUse hook to prevent dangerous operations

# Read JSON input from stdin
$input = $Input | Out-String
try {
    $json = $input | ConvertFrom-Json
    $command = $json.tool_input.command
} catch {
    # If we can't parse JSON, allow the command (fail open)
    exit 0
}

# Exit early if no command
if (-not $command) {
    exit 0
}

# Define destructive patterns with descriptions
$destructivePatterns = @(
    # ============ FILE DELETION ============
    @{ Pattern = 'rm\s+(-[a-zA-Z]*)?r[a-zA-Z]*f'; Desc = 'rm -rf (recursive force delete)' }
    @{ Pattern = 'rm\s+(-[a-zA-Z]*)?f[a-zA-Z]*r'; Desc = 'rm -fr (recursive force delete)' }
    @{ Pattern = 'rm\s+-[a-zA-Z]*\s+/'; Desc = 'rm with flags on root paths' }
    @{ Pattern = 'rm\s+\*'; Desc = 'rm with wildcards' }
    @{ Pattern = 'rm\s+-rf\s+node_modules'; Desc = 'rm -rf node_modules' }
    # Windows file deletion
    @{ Pattern = 'del\s+/s'; Desc = 'del /s (recursive delete)' }
    @{ Pattern = 'del\s+/q'; Desc = 'del /q (quiet delete)' }
    @{ Pattern = 'rmdir\s+/s'; Desc = 'rmdir /s (recursive directory delete)' }
    @{ Pattern = 'Remove-Item.*-Recurse.*-Force'; Desc = 'Remove-Item -Recurse -Force' }
    @{ Pattern = 'Remove-Item.*-Force.*-Recurse'; Desc = 'Remove-Item -Force -Recurse' }
    @{ Pattern = 'ri\s+-r\s+-fo'; Desc = 'ri -r -fo (PowerShell alias for recursive force delete)' }
    
    # ============ GIT DESTRUCTIVE OPERATIONS ============
    # Git reset (all variants)
    @{ Pattern = 'git\s+reset\s+--hard'; Desc = 'git reset --hard' }
    @{ Pattern = 'git\s+reset\s+--mixed'; Desc = 'git reset --mixed' }
    @{ Pattern = 'git\s+reset\s+HEAD~'; Desc = 'git reset HEAD~ (undo commits)' }
    @{ Pattern = 'git\s+reset\s+HEAD\^'; Desc = 'git reset HEAD^ (undo commits)' }
    @{ Pattern = 'git\s+reset\s+[a-f0-9]{7,40}'; Desc = 'git reset to specific commit' }
    # Git clean
    @{ Pattern = 'git\s+clean\s+-[a-zA-Z]*f'; Desc = 'git clean -f (force clean untracked)' }
    @{ Pattern = 'git\s+clean\s+-[a-zA-Z]*d'; Desc = 'git clean -d (clean directories)' }
    # Git force push
    @{ Pattern = 'git\s+push\s+.*--force'; Desc = 'git push --force' }
    @{ Pattern = 'git\s+push\s+-f'; Desc = 'git push -f (force)' }
    @{ Pattern = 'git\s+push\s+.*\+'; Desc = 'git push with + (force)' }
    @{ Pattern = 'git\s+push\s+origin\s+:'; Desc = 'git push origin :branch (delete remote branch)' }
    # Git checkout destructive
    @{ Pattern = 'git\s+checkout\s+--\s+\.'; Desc = 'git checkout -- . (discard all changes)' }
    @{ Pattern = 'git\s+checkout\s+\.'; Desc = 'git checkout . (discard all changes)' }
    # Git restore destructive
    @{ Pattern = 'git\s+restore\s+\.'; Desc = 'git restore . (discard all changes)' }
    @{ Pattern = 'git\s+restore\s+--staged\s+\.'; Desc = 'git restore --staged . (unstage all)' }
    # Git branch delete
    @{ Pattern = 'git\s+branch\s+-D'; Desc = 'git branch -D (force delete branch)' }
    # Git stash destructive
    @{ Pattern = 'git\s+stash\s+drop'; Desc = 'git stash drop' }
    @{ Pattern = 'git\s+stash\s+clear'; Desc = 'git stash clear' }
    # Git reflog expire
    @{ Pattern = 'git\s+reflog\s+expire'; Desc = 'git reflog expire' }
    @{ Pattern = 'git\s+gc\s+--prune'; Desc = 'git gc --prune' }
    
    # ============ GITHUB CLI DESTRUCTIVE ============
    @{ Pattern = 'gh\s+repo\s+delete'; Desc = 'gh repo delete' }
    @{ Pattern = 'gh\s+release\s+delete'; Desc = 'gh release delete' }
    @{ Pattern = 'gh\s+pr\s+close.*--delete-branch'; Desc = 'gh pr close --delete-branch' }
    @{ Pattern = 'gh\s+auth\s+logout'; Desc = 'gh auth logout' }
    @{ Pattern = 'gh\s+repo\s+archive'; Desc = 'gh repo archive' }
    @{ Pattern = 'gh\s+api\s+-X\s+DELETE'; Desc = 'gh api -X DELETE' }
    @{ Pattern = 'gh\s+api\s+--method\s+DELETE'; Desc = 'gh api --method DELETE' }
    
    # ============ DATABASE DESTRUCTIVE ============
    @{ Pattern = 'DROP\s+DATABASE'; Desc = 'DROP DATABASE' }
    @{ Pattern = 'DROP\s+TABLE'; Desc = 'DROP TABLE' }
    @{ Pattern = 'DROP\s+SCHEMA'; Desc = 'DROP SCHEMA' }
    @{ Pattern = 'TRUNCATE\s+TABLE'; Desc = 'TRUNCATE TABLE' }
    @{ Pattern = 'DELETE\s+FROM\s+\w+\s*;'; Desc = 'DELETE FROM table; (no WHERE clause)' }
    @{ Pattern = 'prisma\s+migrate\s+reset'; Desc = 'prisma migrate reset' }
    @{ Pattern = 'prisma\s+db\s+push\s+--force-reset'; Desc = 'prisma db push --force-reset' }
    
    # ============ DOCKER DESTRUCTIVE ============
    @{ Pattern = 'docker\s+system\s+prune'; Desc = 'docker system prune' }
    @{ Pattern = 'docker\s+volume\s+rm'; Desc = 'docker volume rm' }
    @{ Pattern = 'docker\s+volume\s+prune'; Desc = 'docker volume prune' }
    @{ Pattern = 'docker\s+container\s+prune'; Desc = 'docker container prune' }
    @{ Pattern = 'docker\s+image\s+prune\s+-a'; Desc = 'docker image prune -a' }
    @{ Pattern = 'docker\s+compose\s+down\s+-v'; Desc = 'docker compose down -v (removes volumes)' }
    
    # ============ SYSTEM DESTRUCTIVE ============
    @{ Pattern = 'mkfs\.'; Desc = 'mkfs (format filesystem)' }
    @{ Pattern = 'dd\s+.*of=/dev/'; Desc = 'dd to device' }
    @{ Pattern = ':\(\)\{:\|:&\};:'; Desc = 'Fork bomb' }
    @{ Pattern = '>\s*/dev/sd'; Desc = 'Write to disk device' }
    @{ Pattern = 'chmod\s+-R\s+777\s+/'; Desc = 'chmod -R 777 / (dangerous permissions)' }
    @{ Pattern = 'chown\s+-R.*/'; Desc = 'chown -R on root' }
    @{ Pattern = 'format\s+[a-zA-Z]:'; Desc = 'format drive (Windows)' }
    
    # ============ NPM/NODE DESTRUCTIVE ============
    @{ Pattern = 'npm\s+cache\s+clean\s+--force'; Desc = 'npm cache clean --force' }
    @{ Pattern = 'npx\s+kill-port'; Desc = 'npx kill-port' }
)

# Check each pattern
foreach ($item in $destructivePatterns) {
    if ($command -match $item.Pattern) {
        Write-Error "BLOCKED: Destructive command detected!"
        Write-Error "Pattern: $($item.Desc)"
        Write-Error "Command: $command"
        Write-Error ""
        Write-Error "This command has been blocked by the Claude Code safety hook."
        Write-Error "If you need to run this command, please do so manually outside of Claude."
        exit 2  # Exit code 2 blocks the tool and shows stderr to Claude
    }
}

# Command is safe, allow it
exit 0

