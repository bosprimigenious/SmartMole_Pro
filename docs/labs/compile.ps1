# SmartMole Pro 实验报告编译
# 用法: cd docs/labs && .\compile.ps1

$root = ".."
$docs = @(
  @("lab32_threads.typ",  "实验1 初探实验/实验报告_3.2任务与线程.pdf",       "3.2 任务与线程"),
  @("lab_whackmole.typ",  "实验2 基础实验/实验报告_MyWhackMole打地鼠.pdf",   "MyWhackMole 打地鼠"),
  @("lab_xiaozhi.typ",    "实验3 综合实验/实验报告_小智AI语音助手.pdf",      "小智 AI 语音助手")
)

foreach ($d in $docs) {
  Write-Host "编译 $($d[2]) -> $($d[1]) ..."
  typst compile --root $root $d[0] $d[1]
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 清理旧英文文件名
$obsolete = @("lab32_threads.pdf", "lab_whackmole.pdf", "lab_xiaozhi.pdf")
foreach ($f in $obsolete) {
  if (Test-Path $f) {
    Remove-Item $f -Force
    Write-Host "已删除旧文件: $f"
  }
}

Write-Host ""
Write-Host "完成，输出文件："
Get-ChildItem -Recurse "实验*" -Filter "实验报告_*.pdf" | ForEach-Object { "  $($_.FullName.Replace((Get-Location).Path + '\', ''))" }
