# ruff: noqa: E501 -- the embedded dashboard stays dependency-free and auditable.
from __future__ import annotations

import json
import threading
import webbrowser
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from forgehand.config import ForgehandConfig
from forgehand.tasks import TaskRunner


def dashboard_snapshot(config: ForgehandConfig, *, limit: int = 100) -> dict[str, Any]:
    """Build a privacy-minimized, local-worker-only dashboard payload."""
    tasks = TaskRunner(config).list_tasks(limit)
    rows: list[dict[str, Any]] = []
    statuses: Counter[str] = Counter()
    totals = {
        "tasks": 0,
        "tokens": 0,
        "calls": 0,
        "wall_seconds": 0.0,
        "required_gates": 0,
        "passed_gates": 0,
    }
    for task in tasks:
        metrics = task.get("metrics") or {}
        status = str(task.get("status") or "unknown")
        statuses[status] += 1
        totals["tasks"] += 1
        totals["tokens"] += int(metrics.get("total_tokens") or 0)
        totals["calls"] += int(metrics.get("model_calls") or 0)
        totals["wall_seconds"] += float(metrics.get("wall_seconds") or 0)
        gate = task.get("required_command_gate") or {}
        gate_required = bool(gate.get("required_command_ids"))
        gate_passed = bool(gate.get("passed"))
        if gate_required:
            totals["required_gates"] += 1
            totals["passed_gates"] += int(gate_passed)
        rows.append(
            {
                "task_id": task.get("task_id"),
                "status": status,
                "model": task.get("model"),
                "repository": Path(str(task.get("repository_root") or "")).name,
                "summary": task.get("worker_summary"),
                "changed_files": int(task.get("changed_file_count") or 0),
                "tokens": int(metrics.get("total_tokens") or 0),
                "calls": int(metrics.get("model_calls") or 0),
                "invalid_attempts": int(metrics.get("invalid_attempts") or 0),
                "validation_gate": (
                    "passed"
                    if gate_required and gate_passed
                    else "failed"
                    if gate_required
                    else "—"
                ),
                "wall_seconds": float(metrics.get("wall_seconds") or 0),
                "finished_at": task.get("finished_at"),
            }
        )
    totals["wall_seconds"] = round(totals["wall_seconds"], 3)
    return {
        "scope": "local_worker_only",
        "notice": "Tokens are endpoint-reported local-worker usage, not Codex savings.",
        "totals": totals,
        "statuses": dict(statuses),
        "tasks": rows,
    }


HTML = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Forgehand dashboard</title><style>
:root{color-scheme:dark;--bg:#0b0d10;--panel:#13171d;--line:#29313b;--ink:#edf2f7;--muted:#93a1b1;--hot:#f59e0b;--ok:#34d399;--bad:#fb7185}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 80% 0,#27200f 0,transparent 34%),var(--bg);color:var(--ink);font:14px/1.5 Inter,ui-sans-serif,system-ui}
main{max-width:1120px;margin:auto;padding:48px 24px}header{display:flex;justify-content:space-between;gap:24px;align-items:end;margin-bottom:30px}h1{font-size:36px;margin:0;letter-spacing:-1px}h1 span{color:var(--hot)}p{color:var(--muted);margin:6px 0 0}.badge{border:1px solid var(--line);border-radius:999px;padding:7px 11px;color:var(--muted)}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:20px 0}.card,.table-wrap{background:color-mix(in srgb,var(--panel) 92%,transparent);border:1px solid var(--line);border-radius:14px}.card{padding:18px}.label{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.08em}.value{font-size:27px;font-weight:700;margin-top:5px}
.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;min-width:780px}th,td{padding:13px 15px;border-bottom:1px solid var(--line);text-align:left}th{color:var(--muted);font-size:12px}tr:last-child td{border:0}.status{font-weight:700}.success{color:var(--ok)}.blocked,.needs_review{color:var(--bad)}code{color:#fcd34d}footer{color:var(--muted);margin-top:16px;font-size:12px}
@media(max-width:720px){header{align-items:start;flex-direction:column}.cards{grid-template-columns:repeat(2,1fr)}}
</style></head><body><main><header><div><h1>Forge<span>hand</span></h1><p>Bounded local work, compact evidence.</p></div><div class="badge">Read-only · localhost</div></header>
<section class="cards"><div class="card"><div class="label">Tasks</div><div id="tasks" class="value">—</div></div><div class="card"><div class="label">Worker tokens</div><div id="tokens" class="value">—</div></div><div class="card"><div class="label">Model calls</div><div id="calls" class="value">—</div></div><div class="card"><div class="label">Success rate</div><div id="rate" class="value">—</div></div><div class="card"><div class="label">Required gates</div><div id="gates" class="value">—</div></div></section>
<div class="table-wrap"><table><thead><tr><th>Status</th><th>Validation</th><th>Repository</th><th>Summary</th><th>Tokens</th><th>Calls</th><th>Changed</th><th>Finished</th></tr></thead><tbody id="rows"></tbody></table></div>
<footer id="notice"></footer></main><script>
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function refresh(){const d=await fetch('/api/summary',{cache:'no-store'}).then(r=>r.json());const t=d.totals;document.querySelector('#tasks').textContent=t.tasks.toLocaleString();document.querySelector('#tokens').textContent=t.tokens.toLocaleString();document.querySelector('#calls').textContent=t.calls.toLocaleString();document.querySelector('#rate').textContent=t.tasks?Math.round(100*(d.statuses.success||0)/t.tasks)+'%':'—';document.querySelector('#gates').textContent=t.required_gates?`${t.passed_gates}/${t.required_gates}`:'—';document.querySelector('#notice').textContent=d.notice;document.querySelector('#rows').innerHTML=d.tasks.map(x=>`<tr><td class="status ${esc(x.status)}">${esc(x.status)}</td><td class="status ${x.validation_gate==='passed'?'success':x.validation_gate==='failed'?'blocked':''}">${esc(x.validation_gate)}</td><td><code>${esc(x.repository)}</code></td><td>${esc(x.summary||'—')}</td><td>${x.tokens.toLocaleString()}</td><td>${x.calls}</td><td>${x.changed_files}</td><td>${esc(x.finished_at||'—')}</td></tr>`).join('')||'<tr><td colspan="8">No completed tasks yet.</td></tr>'}refresh();setInterval(refresh,5000);
</script></body></html>"""


def serve_dashboard(
    config: ForgehandConfig,
    *,
    port: int = 8765,
    open_browser: bool = True,
) -> None:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path in {"/", "/index.html"}:
                body, content_type, status = HTML.encode(), "text/html; charset=utf-8", 200
            elif self.path == "/api/summary":
                body = json.dumps(dashboard_snapshot(config), separators=(",", ":")).encode()
                content_type, status = "application/json; charset=utf-8", 200
            else:
                body, content_type, status = b"not found", "text/plain; charset=utf-8", 404
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", "default-src 'self' 'unsafe-inline'")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            return

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = f"http://127.0.0.1:{server.server_port}"
    print(f"Forgehand dashboard: {url}")
    if open_browser:
        threading.Timer(0.2, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
