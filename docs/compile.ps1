# SmartMole Pro 项目报告编译
# 用法: cd docs && python compile_all.py
#       或: cd docs && .\compile-all.ps1
# 输出: SmartMolePro_*.pdf（中文文件名，便于识别）
# 答辩 PPT (Slidev 推荐): cd ppt-projects/smartmole-defense/slidev; npm i; npm run setup; npm run dev
# 答辩 PPT (SVG/PPTX): python scripts/build_svg_all.py

$docs = @(
  @("report.typ",     "SmartMolePro_开题报告.pdf",     "开题报告"),
  @("progress.typ",   "SmartMolePro_任务进度报告.pdf", "任务进度报告"),
  @("division.typ",   "SmartMolePro_分工报告.pdf",     "分工报告"),
  @("conclusion.typ", "SmartMolePro_结题报告.pdf",     "结题报告")
)

foreach ($d in $docs) {
  Write-Host "编译 $($d[2]) -> $($d[1]) ..."
  typst compile $d[0] $d[1]
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 清理旧英文文件名（避免与中文版重复混淆）
$obsolete = @(
  "report.pdf", "progress.pdf", "division.pdf", "conclusion.pdf",
  "开题报告.pdf", "进展报告.pdf", "分工报告.pdf"
)
foreach ($f in $obsolete) {
  if (Test-Path $f) {
    Remove-Item $f -Force
    Write-Host "已删除旧文件: $f"
  }
}

Write-Host ""
Write-Host "完成，输出文件："
Get-ChildItem "SmartMolePro_*.pdf" | ForEach-Object { "  $($_.Name)" }
Write-Host ""
Write-Host "实验报告: cd docs && python compile_all.py"
