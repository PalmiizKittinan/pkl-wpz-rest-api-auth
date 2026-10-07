# svn-manager.ps1
# Script จัดการ SVN แบบครบวงจร

param(
    [string]$Action = ""
)

# กำหนดเส้นทางแบบ Dynamic (ไม่ใช้ absolute path)
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$GIT_DIR = $ScriptPath
$ParentDir = Split-Path -Parent $GIT_DIR
$GitFolderName = Split-Path -Leaf $GIT_DIR

if ($GitFolderName -match '-github$') {
    # Convention: <plugin>-github/ + <plugin>-svn/ as siblings
    $SVNFolderName = $GitFolderName -replace '-github$', '-svn'
} elseif (Test-Path (Join-Path $ParentDir "svn")) {
    # Convention: <plugin>/ (this repo) + svn/ as siblings
    $SVNFolderName = "svn"
} else {
    # Fallback: assume <plugin>-svn/ next to this repo
    $SVNFolderName = "$GitFolderName-svn"
}

$SVN_DIR = Join-Path $ParentDir $SVNFolderName
$SVN_TRUNK = Join-Path $SVN_DIR "trunk"
$EXCLUDE_FILE = Join-Path $GIT_DIR "exclude.txt"

Write-Host "Script Path: $ScriptPath" -ForegroundColor Gray
Write-Host "Git Dir: $GIT_DIR" -ForegroundColor Gray
Write-Host "SVN Dir: $SVN_DIR" -ForegroundColor Gray
Write-Host "Exclude File: $EXCLUDE_FILE" -ForegroundColor Gray
Write-Host ""

# ฟังก์ชันอ่านไฟล์ exclude
function Get-ExcludePatterns {
    $patterns = @()

    if (Test-Path $EXCLUDE_FILE) {
        Write-Host "Loading exclude.txt..." -ForegroundColor Yellow
        $content = Get-Content $EXCLUDE_FILE -ErrorAction SilentlyContinue

        foreach ($line in $content) {
            $line = $line.Trim()
            # ข้ามบรรทัดว่างและคอมเมนต์
            if ($line -eq "" -or $line.StartsWith("#")) {
                continue
            }
            $patterns += $line
            Write-Host "  - $line" -ForegroundColor DarkGray
        }

        Write-Host "Loaded $($patterns.Count) patterns" -ForegroundColor Green
    } else {
        Write-Host "Warning: exclude.txt not found at $EXCLUDE_FILE" -ForegroundColor Yellow
        Write-Host "Using default patterns..." -ForegroundColor Yellow

        # ค่า default - ใช้ wildcard เพื่อรองรับทุก plugin
        $patterns = @(
            '.git',
            '.gitignore',
            'node_modules',
            '.idea',
            '.vscode',
            'exclude.txt',
            '*.ps1',
            '*-svn',
            '.DS_Store',
            'Thumbs.db'
        )
    }

    Write-Host ""
    return $patterns
}

# ฟังก์ชันตรวจสอบว่าควร exclude หรือไม่
function Should-Exclude {
    param(
        [string]$ItemName,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        # ตรวจสอบ exact match
        if ($ItemName -eq $pattern) {
            return $true
        }

        # ตรวจสอบ wildcard pattern
        if ($pattern.Contains('*') -or $pattern.Contains('?')) {
            if ($ItemName -like $pattern) {
                return $true
            }
        }

        # ตรวจสอบ directory pattern (ลงท้ายด้วย /)
        if ($pattern.EndsWith('/')) {
            $cleanPattern = $pattern.TrimEnd('/')
            if ($ItemName -eq $cleanPattern) {
                return $true
            }
        }
    }

    return $false
}

function Setup-SvnIgnore {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Setup SVN Ignore Properties" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Patterns ที่แนะนำ
    $recommendedPatterns = @(
        '.idea',
        '.vscode',
        'node_modules',
        '.git',
        '.gitignore',
        '*.log',
        '*.ps1',
        'Thumbs.db',
        '.DS_Store'
    )

    Write-Host "Current svn:ignore for root:" -ForegroundColor Yellow
    $currentIgnore = svn propget svn:ignore . 2>$null
    if ($currentIgnore) {
        $currentIgnore -split "`n" | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor White
        }
    } else {
        Write-Host "  (not set)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Recommended patterns:" -ForegroundColor Yellow
    $recommendedPatterns | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor White
    }

    Write-Host ""
    $apply = Read-Host "Apply recommended patterns? (yes/no)"

    if ($apply -eq "yes" -or $apply -eq "y") {
        Write-Host ""
        Write-Host "Applying svn:ignore patterns..." -ForegroundColor Yellow

        $tempFile = "temp-svn-ignore.txt"
        ($recommendedPatterns -join "`n") | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

        # ตั้งค่าสำหรับ root
        svn propset svn:ignore -F $tempFile .
        Write-Host "  [SET] Root directory" -ForegroundColor Green

        # ตั้งค่าสำหรับ trunk
        if (Test-Path "trunk") {
            svn propset svn:ignore -F $tempFile trunk
            Write-Host "  [SET] Trunk directory" -ForegroundColor Green
        }

        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "svn:ignore properties set successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: These are local properties." -ForegroundColor Yellow
        Write-Host "To commit them to repository, run:" -ForegroundColor Yellow
        Write-Host "  svn ci -m 'Update svn:ignore properties' --username your-username" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Cancelled" -ForegroundColor Yellow
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   SVN Manager for WordPress Plugin" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Sync files to SVN trunk" -ForegroundColor White
    Write-Host "2. Sync and commit to SVN" -ForegroundColor White
    Write-Host "3. Create SVN tag" -ForegroundColor White
    Write-Host "4. Show SVN tags" -ForegroundColor White
    Write-Host "5. Delete SVN tag" -ForegroundColor White
    Write-Host "6. Check SVN status" -ForegroundColor White
    Write-Host "7. Update from SVN repository" -ForegroundColor White
    Write-Host "8. Show exclude patterns" -ForegroundColor White
    Write-Host "9. Setup SVN ignore properties" -ForegroundColor White
    Write-Host "10. Cleanup SVN (revert & reset)" -ForegroundColor White
    Write-Host "11. Exit" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
}

function Sync-ToSVN {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Syncing to SVN" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # ตรวจสอบว่า SVN trunk มีอยู่
    if (-not (Test-Path $SVN_TRUNK)) {
        Write-Host "Error: SVN trunk not found at $SVN_TRUNK" -ForegroundColor Red
        Write-Host "Please checkout SVN first!" -ForegroundColor Yellow
        return
    }

    # โหลด exclude patterns
    $excludePatterns = Get-ExcludePatterns

    # ลบไฟล์เก่าใน trunk
    Write-Host "Cleaning SVN trunk..." -ForegroundColor Yellow
    Get-ChildItem -Path $SVN_TRUNK -Force | Where-Object {
        $_.Name -ne '.svn'
    } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned" -ForegroundColor Green
    Write-Host ""

    # คัดลอกไฟล์
    Write-Host "Copying files..." -ForegroundColor Yellow
    $copiedCount = 0
    $skippedCount = 0

    Get-ChildItem -Path $GIT_DIR -Force | ForEach-Object {
        $shouldExclude = Should-Exclude -ItemName $_.Name -Patterns $excludePatterns

        if ($shouldExclude) {
            Write-Host "  [SKIP] $($_.Name)" -ForegroundColor DarkGray
            $skippedCount++
        } else {
            try {
                Copy-Item -Path $_.FullName -Destination $SVN_TRUNK -Recurse -Force -ErrorAction Stop
                Write-Host "  [COPY] $($_.Name)" -ForegroundColor Green
                $copiedCount++
            } catch {
                Write-Host "  [FAIL] $($_.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Sync completed!" -ForegroundColor Green
    Write-Host "  Copied: $copiedCount" -ForegroundColor White
    Write-Host "  Skipped: $skippedCount" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Sync-AndCommit {
    Sync-ToSVN

    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    # ตั้งค่า svn:ignore ก่อน check status
    Write-Host "Configuring svn:ignore..." -ForegroundColor Yellow

    $svnIgnorePatterns = @(
        '.idea',
        '.vscode',
        'node_modules',
        '.git',
        '.gitignore',
        '*.log',
        'Thumbs.db',
        '.DS_Store',
        '*.ps1'
    )

    $tempIgnoreFile = "temp-svn-ignore.txt"
    ($svnIgnorePatterns -join "`n") | Out-File -FilePath $tempIgnoreFile -Encoding UTF8 -NoNewline

    svn propset svn:ignore -F $tempIgnoreFile . 2>$null
    svn propset svn:ignore -F $tempIgnoreFile trunk 2>$null

    Remove-Item $tempIgnoreFile -Force -ErrorAction SilentlyContinue

    Write-Host "svn:ignore configured" -ForegroundColor Green
    Write-Host ""

    Write-Host "SVN Status:" -ForegroundColor Yellow

    # แสดง status แต่กรองไฟล์ที่ ignore
    $status = svn status

    if ($status) {
        $filteredStatus = $status | Where-Object {
            $line = $_
            $shouldShow = $true

            foreach ($pattern in $svnIgnorePatterns) {
                $cleanPattern = $pattern.Replace('*', '').Replace('?', '')
                if ($line -match [regex]::Escape($cleanPattern)) {
                    $shouldShow = $false
                    break
                }
            }

            $shouldShow
        }

        if ($filteredStatus) {
            $filteredStatus | ForEach-Object {
                Write-Host $_
            }
        } else {
            Write-Host "Working directory is clean (all changes are ignored files)" -ForegroundColor Green
        }
    } else {
        Write-Host "Working directory is clean" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Adding new files..." -ForegroundColor Yellow
    svn add trunk/* --force 2>$null

    Write-Host ""
    $commitMessage = Read-Host "Enter commit message"
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "Update from Git repository"
    }

    $username = Read-Host "Enter WordPress.org username"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host ""
        Write-Host "Username is required!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host ""
    Write-Host "Committing..." -ForegroundColor Yellow
    svn ci -m "$commitMessage" --username $username

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Committed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Commit failed!" -ForegroundColor Red
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Create-Tag {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    $version = Read-Host "Enter version number (e.g., 1.0.0)"
    if ([string]::IsNullOrWhiteSpace($version)) {
        Write-Host "Version is required!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    $username = Read-Host "Enter WordPress.org username"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username is required!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    # ตรวจสอบว่า tag มีอยู่ใน SVN หรือไม่
    $tagPath = "tags/$version"
    $tagExists = $false

    # ตรวจสอบจาก svn status
    $svnStatus = svn status $tagPath 2>$null
    if ($svnStatus) {
        $tagExists = $true
        Write-Host ""
        Write-Host "Tag $version exists in SVN status!" -ForegroundColor Yellow
        Write-Host "Status: $svnStatus" -ForegroundColor Gray

        # ถ้า tag ถูก schedule for addition แต่ไฟล์หาย ให้ revert ก่อน
        if ($svnStatus -match '^\s*A') {
            Write-Host "Reverting incomplete tag..." -ForegroundColor Yellow
            svn revert -R $tagPath 2>$null
            svn update $tagPath 2>$null
        }

        $overwrite = Read-Host "Overwrite? (yes/no)"
        if ($overwrite -ne "yes" -and $overwrite -ne "y") {
            Write-Host "Cancelled" -ForegroundColor Red
            Pop-Location
            Read-Host "Press Enter to continue"
            return
        }

        # ลบ tag แบบถูกวิธี
        Write-Host "Removing existing tag..." -ForegroundColor Yellow
        svn delete $tagPath --force 2>$null
        svn commit $tagPath -m "Removing tag $version for recreation" --username $username 2>$null
        svn update 2>$null
    } elseif (Test-Path $tagPath) {
        # มี folder อยู่แต่ไม่อยู่ใน SVN
        Write-Host ""
        Write-Host "Tag folder exists locally but not in SVN" -ForegroundColor Yellow
        Write-Host "Cleaning up..." -ForegroundColor Yellow
        Remove-Item -Path $tagPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ทำความสะอาดก่อนสร้าง tag ใหม่
    Write-Host ""
    Write-Host "Updating SVN..." -ForegroundColor Yellow
    svn update --force 2>$null

    # สร้าง tag ใหม่
    Write-Host "Creating tag $version from trunk..." -ForegroundColor Yellow
    svn cp trunk $tagPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Failed to create tag!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    # Commit
    Write-Host "Committing tag..." -ForegroundColor Yellow
    Write-Host "Username: $username" -ForegroundColor Gray
    Write-Host ""

    svn ci -m "Tagging version $version" --username $username

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Tag $version created successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Tag creation failed!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Check SVN status: svn status" -ForegroundColor White
        Write-Host "2. Cleanup: svn cleanup" -ForegroundColor White
        Write-Host "3. Update: svn update" -ForegroundColor White
        Write-Host "4. Try again" -ForegroundColor White
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-Tags {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SVN Tags" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # ตรวจสอบว่ามี tags directory หรือไม่
    if (-not (Test-Path "tags")) {
        Write-Host "Tags directory not found" -ForegroundColor Yellow
        Pop-Location
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }

    # ดึง plugin slug จากชื่อ Git folder (ไม่ใช่ SVN folder เพราะอาจชื่อแค่ "svn")
    $pluginSlug = $GitFolderName -replace '-github$', ''
    $repoUrl = "https://plugins.svn.wordpress.org/$pluginSlug"

    # ดึง tags จาก local
    Write-Host "Local tags:" -ForegroundColor Yellow
    $localTags = @{}

    Get-ChildItem "tags" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $tagName = $_.Name
        $tagPath = $_.FullName

        # หา readme.txt ใน tag
        $readmePath = Join-Path $tagPath "readme.txt"
        $version = "N/A"
        $stableTag = "N/A"

        if (Test-Path $readmePath) {
            $readmeContent = Get-Content $readmePath -Raw -ErrorAction SilentlyContinue

            # ดึง version จาก changelog
            if ($readmeContent -match "==\s*Changelog\s*==[\s\S]*?=\s*($tagName)") {
                $version = $tagName
            }

            # ดึง stable tag
            if ($readmeContent -match "Stable tag:\s*(.+)") {
                $stableTag = $matches[1].Trim()
            }
        }

        $localTags[$tagName] = @{
            Version = $version
            StableTag = $stableTag
            Path = $tagPath
        }
    }

    if ($localTags.Count -gt 0) {
        $localTags.Keys | Sort-Object | ForEach-Object {
            $info = $localTags[$_]
            Write-Host "  [LOCAL] " -NoNewline -ForegroundColor White
            Write-Host $_ -NoNewline -ForegroundColor Cyan

            if ($info.StableTag -eq $_) {
                Write-Host " (STABLE)" -NoNewline -ForegroundColor Green
            }

            Write-Host ""
        }
    } else {
        Write-Host "  No local tags" -ForegroundColor DarkGray
    }

    Write-Host ""

    # ดึง tags จาก repository
    Write-Host "Remote tags (from repository):" -ForegroundColor Yellow
    Write-Host "URL: $repoUrl/tags/" -ForegroundColor DarkGray
    Write-Host "Fetching..." -ForegroundColor DarkGray
    Write-Host ""

    $remoteTags = svn list "$repoUrl/tags/" 2>$null

    if ($remoteTags) {
        $remoteTags | ForEach-Object {
            $tagName = $_.TrimEnd('/')
            if ($tagName) {
                # เช็คว่ามีใน local หรือไม่
                if ($localTags.ContainsKey($tagName)) {
                    Write-Host "  [SYNCED] " -NoNewline -ForegroundColor Green
                    Write-Host $tagName -ForegroundColor Cyan
                } else {
                    Write-Host "  [REMOTE] " -NoNewline -ForegroundColor Yellow
                    Write-Host $tagName -ForegroundColor Cyan
                }
            }
        }
    } else {
        Write-Host "  Unable to fetch remote tags" -ForegroundColor Red
        Write-Host "  This might be due to network issues or repository not found" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    # สรุปจำนวน
    $localCount = $localTags.Count
    $remoteCount = if ($remoteTags) { ($remoteTags | Where-Object { $_ }).Count } else { 0 }

    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Local tags:  $localCount" -ForegroundColor White
    Write-Host "  Remote tags: $remoteCount" -ForegroundColor White

    # แสดง stable tag
    $stableTagInfo = $localTags.Values | Where-Object { $_.StableTag -ne "N/A" } | Select-Object -First 1
    if ($stableTagInfo) {
        Write-Host "  Stable tag:  $($stableTagInfo.StableTag)" -ForegroundColor Green
    }

    # แสดง legend
    Write-Host ""
    Write-Host "Legend:" -ForegroundColor Yellow
    Write-Host "  [LOCAL]  - Tag exists only locally (not yet pushed)" -ForegroundColor White
    Write-Host "  [REMOTE] - Tag exists only on repository (run 'svn update' to sync)" -ForegroundColor Yellow
    Write-Host "  [SYNCED] - Tag exists both locally and remotely" -ForegroundColor Green
    Write-Host "  (STABLE) - Current stable version" -ForegroundColor Green

    # แสดงคำแนะนำ
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Yellow

    if ($remoteCount -gt $localCount) {
        Write-Host "  → Run option 7 (Update from SVN) to sync remote tags" -ForegroundColor Cyan
    }

    if ($localCount -eq 0) {
        Write-Host "  → Run option 3 (Create SVN tag) to create your first tag" -ForegroundColor Cyan
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Delete-Tag {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Delete SVN Tag" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # แสดง tags ที่มีอยู่
    Write-Host "Available tags:" -ForegroundColor Yellow
    if (Test-Path "tags") {
        $tags = Get-ChildItem "tags" -Directory | Select-Object -ExpandProperty Name
        if ($tags.Count -eq 0) {
            Write-Host "  No tags found" -ForegroundColor DarkGray
        } else {
            $tags | ForEach-Object {
                Write-Host "  - $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  Tags directory not found" -ForegroundColor DarkGray
    }

    Write-Host ""
    $version = Read-Host "Enter tag version to delete (e.g., 1.1.0)"

    if ([string]::IsNullOrWhiteSpace($version)) {
        Write-Host "Version is required!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    $tagPath = "tags/$version"

    # ตรวจสอบว่า tag มีอยู่หรือไม่
    $tagExists = $false

    # เช็คใน SVN
    svn list $tagPath 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $tagExists = $true
    } elseif (Test-Path $tagPath) {
        $tagExists = $true
    }

    if (-not $tagExists) {
        Write-Host ""
        Write-Host "Tag $version not found!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    # ยืนยันการลบ
    Write-Host ""
    Write-Host "WARNING: This will permanently delete tag $version" -ForegroundColor Red
    Write-Host "This action cannot be undone!" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'DELETE' to confirm"

    if ($confirmation -ne "DELETE") {
        Write-Host ""
        Write-Host "Cancelled" -ForegroundColor Yellow
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    # ถาม username
    $username = Read-Host "Enter WordPress.org username"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username is required!" -ForegroundColor Red
        Pop-Location
        Read-Host "Press Enter to continue"
        return
    }

    # ลบ tag
    Write-Host ""
    Write-Host "Deleting tag $version..." -ForegroundColor Yellow
    svn delete $tagPath --force

    # Commit
    Write-Host "Committing deletion..." -ForegroundColor Yellow
    svn ci -m "Remove tag $version" --username $username

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Tag $version deleted successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Note: It may take 5-15 minutes for WordPress.org to update" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Deletion failed!" -ForegroundColor Red
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Check-Status {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SVN Status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # ไฟล์/โฟลเดอร์ที่ต้องการ ignore
    $ignorePatterns = @(
        '.idea',
        '.vscode',
        'node_modules',
        '.git',
        '.gitignore',
        '*.log',
        '*.ps1',
        'Thumbs.db',
        '.DS_Store',
        'temp-svn-ignore.txt'
    )

    $status = svn status

    if ($status) {
        $filteredStatus = $status | Where-Object {
            $line = $_
            $shouldShow = $true

            foreach ($pattern in $ignorePatterns) {
                $cleanPattern = $pattern.Replace('*', '').Replace('?', '')
                if ($line -match [regex]::Escape($cleanPattern)) {
                    $shouldShow = $false
                    break
                }
            }

            $shouldShow
        }

        if ($filteredStatus) {
            $filteredStatus | ForEach-Object {
                $statusChar = $_.Substring(0, 1)
                $file = $_.Substring(8)

                switch ($statusChar) {
                    "M" { Write-Host "[MODIFIED]  " -NoNewline -ForegroundColor Yellow; Write-Host $file }
                    "A" { Write-Host "[ADDED]     " -NoNewline -ForegroundColor Green; Write-Host $file }
                    "D" { Write-Host "[DELETED]   " -NoNewline -ForegroundColor Red; Write-Host $file }
                    "?" { Write-Host "[UNTRACKED] " -NoNewline -ForegroundColor DarkGray; Write-Host $file }
                    "!" { Write-Host "[MISSING]   " -NoNewline -ForegroundColor Red; Write-Host $file }
                    "C" { Write-Host "[CONFLICT]  " -NoNewline -ForegroundColor Red; Write-Host $file }
                    default { Write-Host $_ }
                }
            }

            # แสดงจำนวนไฟล์ที่ถูก ignore
            $ignoredCount = $status.Count - $filteredStatus.Count
            if ($ignoredCount -gt 0) {
                Write-Host ""
                Write-Host "($ignoredCount files/folders ignored)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "Working directory is clean (all changes are ignored files)" -ForegroundColor Green

            # แสดงไฟล์ที่ถูก ignore
            Write-Host ""
            Write-Host "Ignored files:" -ForegroundColor DarkGray
            $status | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "Working directory is clean" -ForegroundColor Green
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Update-FromSVN {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR
    Write-Host ""
    Write-Host "Updating from SVN..." -ForegroundColor Yellow
    svn update
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Updated successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Update failed!" -ForegroundColor Red
    }
    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-ExcludePatterns {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Exclude Patterns" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "File: $EXCLUDE_FILE" -ForegroundColor Gray
    Write-Host ""

    if (Test-Path $EXCLUDE_FILE) {
        $lineNum = 1
        Get-Content $EXCLUDE_FILE | ForEach-Object {
            if ($_.Trim().StartsWith("#")) {
                Write-Host "$lineNum : $_" -ForegroundColor DarkGray
            } elseif ($_.Trim() -eq "") {
                Write-Host "$lineNum :" -ForegroundColor DarkGray
            } else {
                Write-Host "$lineNum : $_" -ForegroundColor Green
            }
            $lineNum++
        }
    } else {
        Write-Host "File not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Default patterns will be used:" -ForegroundColor Yellow
        $patterns = Get-ExcludePatterns
        $patterns | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Read-Host "Press Enter to continue"
}


function Cleanup-SVN {
    if (-not (Test-Path $SVN_DIR)) {
        Write-Host "Error: SVN directory not found" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Push-Location $SVN_DIR

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SVN Cleanup & Reset" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Checking SVN status..." -ForegroundColor Yellow
    $status = svn status

    if ($status) {
        Write-Host ""
        Write-Host "Current status:" -ForegroundColor Yellow
        svn status
        Write-Host ""

        $cleanup = Read-Host "Do you want to revert all changes? (yes/no)"
        if ($cleanup -eq "yes" -or $cleanup -eq "y") {
            Write-Host ""
            Write-Host "Reverting all changes..." -ForegroundColor Yellow
            svn revert -R .

            Write-Host "Removing unversioned files..." -ForegroundColor Yellow
            svn status | Where-Object { $_ -match '^\?' } | ForEach-Object {
                $file = $_.Substring(8)
                Write-Host "  Removing: $file" -ForegroundColor DarkGray
                Remove-Item -Path $file -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-Host "Running SVN cleanup..." -ForegroundColor Yellow
    svn cleanup

    Write-Host "Updating from repository..." -ForegroundColor Yellow
    svn update --force

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "SVN cleaned up successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Cleanup completed with warnings" -ForegroundColor Yellow
    }

    Pop-Location
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# Main Loop
if ([string]::IsNullOrWhiteSpace($Action)) {
    do {
        Show-Menu
        $choice = Read-Host "Select option (1-11)"

        switch ($choice) {
            "1" {
                Sync-ToSVN
                Read-Host "Press Enter to continue"
            }
            "2" {
                Sync-AndCommit
            }
            "3" {
                Create-Tag
            }
            "4" {
                Show-Tags
            }
            "5" {
                Delete-Tag
            }
            "6" {
                Check-Status
            }
            "7" {
                Update-FromSVN
            }
            "8" {
                Show-ExcludePatterns
            }
            "9" {
                Setup-SvnIgnore
            }
            "10" {
                Cleanup-SVN
            }
            "11" {
                Write-Host ""
                Write-Host "Goodbye!" -ForegroundColor Cyan
                Write-Host ""
                exit
            }
            default {
                Write-Host ""
                Write-Host "Invalid option!" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
} else {
    switch ($Action.ToLower()) {
        "sync" {
            Sync-ToSVN
            Read-Host "Press Enter to exit"
        }
        "commit" { Sync-AndCommit }
        "tag" { Create-Tag }
        "show-tags" { Show-Tags }
        "delete-tag" { Delete-Tag }
        "status" { Check-Status }
        "update" { Update-FromSVN }
        "show-excludes" { Show-ExcludePatterns }
        "setup-ignore" { Setup-SvnIgnore }
        "cleanup" { Cleanup-SVN }
        default {
            Write-Host "Unknown action: $Action" -ForegroundColor Red
        }
    }
}