#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Robust hy-3d batch orchestrator: submit 5 jobs (max 2 concurrent, daily limit 5),
poll, download GLB + preview. Resumable via manifest.json (running job_ids survive server-side)."""
import subprocess, json, sys, os, time, urllib.request, argparse

PYTHON = "/Users/weihu/.workbuddy/binaries/python/versions/3.13.12/bin/python"
SCRIPT = "/Users/weihu/.workbuddy/plugins/cache/workbuddy-builtin/skill-buddy-multimodal-generation/0.1.0/scripts/buddy-cloud.py"
MAX_CONCURRENT = 2
DAILY_LIMIT = 5
POLL = 30
FACE_COUNT = 22000  # keep LowPoly light for clean rigging + fast Godot import


def log(m):
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def buddy(args, token):
    p = subprocess.run([PYTHON, SCRIPT] + args + ["--token-stdin"],
                       input=token, capture_output=True, text=True, timeout=180)
    return p.stdout, p.stderr, p.returncode


def extract_json(text):
    start = text.find("{")
    if start == -1:
        return None
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(text[start:i + 1])
                    except Exception:
                        return None
    return None


def submit(prompt, token):
    args = ["3d", prompt, "--generate-type", "LowPoly", "--model", "3.0",
            "--face-count", str(FACE_COUNT), "--no-poll"]
    out, err, rc = buddy(args, token)
    if rc != 0 and "daily submit limit" in out:
        return None, "DAILY"
    if rc != 0 and "concurrent slot" in out:
        return None, "CONCURRENT"
    d = extract_json(out)
    if d and "job_id" in d:
        return d["job_id"], "OK"
    return None, f"UNKNOWN:{out[:240]}"


def status(jid, token):
    out, err, rc = buddy(["status", jid, "--type", "3d"], token)
    return extract_json(out)


def download(url, path):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=240) as r, open(path, "wb") as f:
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            f.write(chunk)
    return os.path.getsize(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("jobs")
    ap.add_argument("out")
    ap.add_argument("--budget", type=int, default=3600)
    a = ap.parse_args()
    token = sys.stdin.read().strip()
    if not token:
        log("NO TOKEN on stdin"); return
    cfg = json.load(open(a.jobs, encoding="utf-8"))
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    jobs = cfg.get("jobs", [])
    running = {}
    results = {}
    queue = list(jobs)
    submitted = 0
    start = time.time()

    while (queue or running) and (time.time() - start) < a.budget:
        while len(running) < MAX_CONCURRENT and queue and submitted < DAILY_LIMIT:
            j = queue.pop(0)
            name = j["name"]
            jid, code = submit(j["prompt"], token)
            if code == "OK" and jid:
                running[name] = {"jid": jid, "job": j}
                submitted += 1
                log(f"SUBMIT {name} -> {jid}")
            elif code == "DAILY":
                log("DAILY LIMIT reached; stop submitting.")
                queue.insert(0, j)
                submitted = DAILY_LIMIT
                break
            elif code == "CONCURRENT":
                log(f"CONCURRENT for {name}; re-queue + wait.")
                queue.insert(0, j)
                time.sleep(15)
                break
            else:
                log(f"SUBMIT FAIL {name}: {code}; re-queue + wait.")
                queue.insert(0, j)
                time.sleep(15)
                break
            time.sleep(3)

        done = []
        for name, info in list(running.items()):
            st = status(info["jid"], token)
            if not st:
                log(f"STATUS_PARSE_FAIL {name}")
                continue
            s = str(st.get("status", "")).upper()
            if s in {"DONE", "SUCCESS", "SUCCEEDED"}:
                results[name] = st
                done.append(name)
                files = (st.get("raw_result", {}) or {}).get("ResultFile3Ds", []) or []
                log(f"FINISHED {name} files={len(files)}")
            elif s in {"FAILED", "FAIL", "ERROR"}:
                results[name] = st
                done.append(name)
                log(f"FAILED {name}")
            else:
                log(f"POLLING {name} status={s}")
        for n in done:
            del running[n]

        if running:
            time.sleep(POLL)
        elif queue and submitted >= DAILY_LIMIT:
            log(f"daily exhausted; {len(queue)} unsubmitted. exit.")
            break
        else:
            time.sleep(POLL)

    items = []
    for name, st in results.items():
        files = (st.get("raw_result", {}) or {}).get("ResultFile3Ds", []) or []
        glb = next((f.get("Url") for f in files if f.get("Type") == "GLB"), None)
        prev = next((f.get("PreviewImageUrl") for f in files if f.get("PreviewImageUrl")), None)
        e = {"name": name, "status": st.get("status")}
        if glb:
            p = os.path.join(out, f"{name}_lowpoly.glb")
            try:
                sz = download(glb, p)
                e["glb"] = p
                e["glb_size"] = sz
                log(f"DOWNLOAD {name} GLB {sz}B -> {p}")
            except Exception as ex:
                log(f"GLB DL FAIL {name}: {ex}")
        if prev:
            p = os.path.join(out, f"{name}_lowpoly_preview.png")
            try:
                sz = download(prev, p)
                e["preview"] = p
                log(f"DOWNLOAD {name} preview {sz}B")
            except Exception as ex:
                log(f"PREVIEW DL FAIL {name}: {ex}")
        items.append(e)

    manifest = {
        "finished": len(results),
        "queued": len(queue),
        "running": {k: v["jid"] for k, v in running.items()},
        "items": items,
    }
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    log(f"DONE. finished={len(results)} queued={len(queue)} running={len(running)}; manifest saved.")


if __name__ == "__main__":
    main()
