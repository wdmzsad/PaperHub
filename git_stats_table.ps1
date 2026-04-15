# git_stats_table.ps1
param(
    [string]$StartDate = "2025-01-01",
    [string]$EndDate = "2025-12-31"
)

function Get-GitStats {
    # 1. 获取提交统计
    $commits = git log --all --no-merges --since="$StartDate" --until="$EndDate" --format="%aN"
    $commitStats = $commits | Group-Object | Sort-Object Count -Descending
    
    # 2. 获取行数统计
    $output = git log --all --no-merges --since="$StartDate" --until="$EndDate" --format="%aN" --numstat
    $authorStats = @{}
    $currentAuthor = $null
    
    foreach ($line in $output -split "`n") {
        if ($line -match '^[^\t]+$') {
            $currentAuthor = $line.Trim()
            if (-not $authorStats.ContainsKey($currentAuthor)) {
                $authorStats[$currentAuthor] = @{Add = 0; Del = 0; Commit = 0}
            }
        } elseif ($line -match '^(\d+|\-)\s+(\d+|\-)\s+') {
            $parts = $line -split '\t'
            $add = if ($parts[0] -eq '-') {0} else {[int]$parts[0]}
            $del = if ($parts[1] -eq '-') {0} else {[int]$parts[1]}
            
            if ($currentAuthor) {
                $authorStats[$currentAuthor].Add += $add
                $authorStats[$currentAuthor].Del += $del
            }
        }
    }
    
    # 3. 合并提交次数
    foreach ($stat in $commitStats) {
        if ($authorStats.ContainsKey($stat.Name)) {
            $authorStats[$stat.Name].Commit = $stat.Count
        }
    }
    
    return $authorStats
}

function Format-AsTable($stats) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "        Git 贡献统计汇总表格" -ForegroundColor Green
    Write-Host "        时间段: $StartDate 到 $EndDate" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # 表格1：总览
    Write-Host "`n表1：贡献总览" -ForegroundColor Yellow
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Cyan
    Write-Host "| 排名 | 作者            | 提交次数   | 新增行数   | 删除行数   | 净增行数 |" -ForegroundColor Cyan
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Cyan
    
    $rank = 1
    $sortedStats = $stats.GetEnumerator() | Sort-Object { $_.Value.Add - $_.Value.Del } -Descending
    foreach ($author in $sortedStats) {
        $add = $author.Value.Add
        $del = $author.Value.Del
        $net = $add - $del
        $commit = $author.Value.Commit
        
        Write-Host ("| {0,2} | {1,-16} | {2,10} | {3,10} | {4,10} | {5,8} |" -f 
            $rank, 
            $author.Key.Substring(0, [Math]::Min(16, $author.Key.Length)),
            $commit,
            $add,
            $del,
            $net
        )
        $rank++
    }
    
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Cyan
    
    # 统计总计
    $totalAdd = ($stats.Values.Add | Measure-Object -Sum).Sum
    $totalDel = ($stats.Values.Del | Measure-Object -Sum).Sum
    $totalNet = $totalAdd - $totalDel
    $totalCommit = ($stats.Values.Commit | Measure-Object -Sum).Sum
    
    Write-Host "| 总计 | $($stats.Count)人          | $($totalCommit) | $($totalAdd) | $($totalDel) | $($totalNet) |" -ForegroundColor Yellow
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Cyan
    
    # 表格2：效率排名
    Write-Host "`n表2：贡献效率排名（新增/删除比例）" -ForegroundColor Yellow
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Magenta
    Write-Host "| 排名 | 作者            | 新增行数   | 删除行数   | 效率比     | 净增/提交 |" -ForegroundColor Magenta
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Magenta
    
    $rank = 1
    $efficiencyStats = $stats.GetEnumerator() | Sort-Object { 
        if ($_.Value.Del -eq 0) { 999 } else { $_.Value.Add / $_.Value.Del }
    } -Descending
    
    foreach ($author in $efficiencyStats) {
        $add = $author.Value.Add
        $del = $author.Value.Del
        $net = $add - $del
        $commit = $author.Value.Commit
        
        $ratio = if ($del -eq 0) { "∞" } else { "{0:F1}:1" -f ($add / $del) }
        $perCommit = if ($commit -eq 0) { "0" } else { [math]::Round($net / $commit) }
        
        Write-Host ("| {0,2} | {1,-16} | {2,10} | {3,10} | {4,10} | {5,8} |" -f 
            $rank,
            $author.Key.Substring(0, [Math]::Min(16, $author.Key.Length)),
            $add,
            $del,
            $ratio,
            $perCommit
        )
        $rank++
    }
    
    Write-Host "+----+------------------+------------+------------+------------+----------+" -ForegroundColor Magenta
}

# 执行统计
Write-Host "正在获取 Git 统计信息..." -ForegroundColor Gray
$stats = Get-GitStats
Format-AsTable $stats

# 输出为CSV格式
Write-Host "`n`nCSV格式（可复制到Excel）:" -ForegroundColor Green
Write-Host "作者,提交次数,新增行数,删除行数,净增行数,效率比,净增/提交"
$sortedStats = $stats.GetEnumerator() | Sort-Object { $_.Value.Add - $_.Value.Del } -Descending
foreach ($author in $sortedStats) {
    $add = $author.Value.Add
    $del = $author.Value.Del
    $net = $add - $del
    $commit = $author.Value.Commit
    $ratio = if ($del -eq 0) { "∞" } else { "{0:F1}" -f ($add / $del) }
    $perCommit = if ($commit -eq 0) { "0" } else { [math]::Round($net / $commit) }
    
    Write-Host "$($author.Key),$commit,$add,$del,$net,$ratio,$perCommit"
}