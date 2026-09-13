/**
 * 前端 CSV 导出工具：把对象数组转 CSV 并触发浏览器下载
 * - 自动加 UTF-8 BOM，Excel 直接打开不乱码
 * - 值内逗号/引号/换行自动转义
 */
export function exportCsv(filename: string, columns: { key: string; label: string }[], rows: Record<string, any>[]) {
  const esc = (v: any): string => {
    const s = v === null || v === undefined ? "" : String(v);
    if (/[",\n\r]/.test(s)) {
      return `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  };

  const header = columns.map((c) => esc(c.label)).join(",");
  const body = rows.map((r) => columns.map((c) => esc(r[c.key])).join(",")).join("\n");
  const csv = "\ufeff" + header + "\n" + body;

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}_${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
