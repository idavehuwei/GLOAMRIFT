#!/usr/bin/env python3
"""Tencent HY 3D: validate, submit once, resume queries, download raw GLB.

Uses only Python's standard library. No secrets, image payloads, signed URLs,
or Authorization headers are printed. Raw generation is NOT a rigged asset.
"""
import argparse
import base64
import datetime
import fcntl
import getpass
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CONFIG = Path(__file__).with_name('jobs.json')
STATE = ROOT / '.hunyuan3d' / 'state.json'
HOST = 'ai3d.tencentcloudapi.com'
VERSION = '2025-05-13'


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def credentials():
    sid = os.environ.get('TENCENTCLOUD_SECRET_ID', '')
    key = os.environ.get('TENCENTCLOUD_SECRET_KEY', '')
    token = os.environ.get('TENCENTCLOUD_SESSION_TOKEN', '')
    if not sid and not key:
        local = STATE.parent / 'credentials.json'
        if local.is_file():
            stored = json.loads(local.read_text())
            sid, key, token = stored.get('secret_id', ''), stored.get('secret_key', ''), stored.get('session_token', '')
    if not sid or not key:
        raise RuntimeError('Missing Tencent Cloud credentials; run configure in your terminal. No task submitted.')
    return sid, key, token


def signed_headers(action, payload, sid, key, token='', timestamp=None):
    timestamp = int(time.time()) if timestamp is None else timestamp
    date = datetime.datetime.fromtimestamp(timestamp, datetime.timezone.utc).strftime('%Y-%m-%d')
    content_type = 'application/json; charset=utf-8'
    headers = 'content-type;host;x-tc-action'
    canonical_headers = f'content-type:{content_type}\nhost:{HOST}\nx-tc-action:{action.lower()}\n'
    digest = lambda data: hashlib.sha256(data).hexdigest()
    canonical = f'POST\n/\n\n{canonical_headers}\n{headers}\n{digest(payload)}'
    scope = f'{date}/ai3d/tc3_request'
    to_sign = f'TC3-HMAC-SHA256\n{timestamp}\n{scope}\n{digest(canonical.encode())}'
    sign = lambda secret, value: hmac.new(secret, value.encode(), hashlib.sha256).digest()
    date_key = sign(('TC3' + key).encode(), date)
    service_key = sign(date_key, 'ai3d')
    signing_key = sign(service_key, 'tc3_request')
    signature = sign(signing_key, to_sign).hex()
    result = {
        'Authorization': f'TC3-HMAC-SHA256 Credential={sid}/{scope}, SignedHeaders={headers}, Signature={signature}',
        'Content-Type': content_type, 'Host': HOST,
        'X-TC-Action': action, 'X-TC-Version': VERSION,
        'X-TC-Timestamp': str(timestamp),
        'X-TC-Region': os.environ.get('TENCENTCLOUD_REGION', 'ap-guangzhou'),
    }
    if token:
        result['X-TC-Token'] = token
    return result


def api(action, params):
    body = json.dumps(params, separators=(',', ':'), ensure_ascii=False).encode()
    headers = signed_headers(action, body, *credentials())
    request = urllib.request.Request('https://' + HOST, data=body, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            result = json.load(response)['Response']
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError) as exc:
        # A submit may have reached the server. Never blindly repeat it.
        raise RuntimeError(f'API transport/response error ({type(exc).__name__}); inspect state before retrying.') from None
    if result.get('Error'):
        code = result['Error'].get('Code', 'Unknown')
        raise RuntimeError('Tencent API error: ' + str(code))
    return result


def prepare(config):
    params = config['parameters']
    if params.get('Model') != '3.1' or params.get('GenerateType') != 'Normal':
        raise ValueError('This first batch requires 3.1 Normal for textured source meshes.')
    if not 3000 <= params['FaceCount'] <= 1500000:
        raise ValueError('FaceCount out of range')
    if set(params) - {'Model', 'GenerateType', 'EnablePBR', 'FaceCount'}:
        raise ValueError('Unexpected parameters: do not mix image and text inputs')
    prepared = []
    ids = set()
    for item in config['jobs']:
        if not re.fullmatch(r'[a-z0-9_]+', item['id']) or item['id'] in ids:
            raise ValueError('Invalid or duplicate asset ID')
        ids.add(item['id'])
        path = (ROOT / item['image']).resolve()
        if not path.is_relative_to(ROOT):
            raise ValueError('Image must be inside this project')
        data = path.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Expected a PNG reference')
        width, height = struct.unpack('>II', data[16:24])
        if not (128 <= width <= 5000 and 128 <= height <= 5000) or len(data) > 6_000_000:
            raise ValueError('Image exceeds documented size/resolution limits')
        payload = dict(params, ImageBase64=base64.b64encode(data).decode())
        fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
        prepared.append((item, payload, fingerprint))
    return prepared


def validate_glb(data):
    if len(data) < 20:
        raise ValueError('Truncated GLB')
    magic, version, length, chunk_length, chunk_type = struct.unpack_from('<4sIIII', data)
    if magic != b'glTF' or version != 2 or length != len(data) or chunk_type != 0x4E4F534A:
        raise ValueError('Invalid GLB header')
    if 20 + chunk_length > len(data):
        raise ValueError('Truncated GLB JSON')
    model = json.loads(data[20:20 + chunk_length])
    if not model.get('meshes'):
        raise ValueError('GLB contains no geometry')
    for value in model.get('buffers', []) + model.get('images', []):
        uri = value.get('uri', '')
        if uri and not uri.startswith('data:'):
            raise ValueError('GLB has external dependencies; package them before import')
    return {k: len(model.get(k, [])) for k in ['meshes', 'materials', 'images', 'skins', 'animations']}


def download_glb(url, target):
    if urllib.parse.urlparse(url).scheme != 'https':
        raise ValueError('Expected an HTTPS result URL')
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read(512 * 1024 * 1024 + 1)
    except (urllib.error.URLError, TimeoutError, OSError):
        raise RuntimeError('GLB download failed; poll again to resume without resubmitting.') from None
    if len(data) > 512 * 1024 * 1024:
        raise ValueError('Unexpectedly large GLB')
    summary = validate_glb(data)
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_suffix('.download')
    temp.write_bytes(data)
    temp.replace(target)
    return dict(summary, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())


def submit(prepared, state, state_path=STATE):
    credentials()  # Check BEFORE persisting a submission intent.
    for item, payload, fingerprint in prepared:
        key = item['id']
        entry = state.get(key)
        if entry:
            if entry['fingerprint'] != fingerprint:
                raise RuntimeError(f'{key}: input changed; use a new versioned asset ID.')
            if not entry.get('job_id'):
                raise RuntimeError(f'{key}: previous submission has no JobId; reconcile in API Inspector, then adopt it.')
            print(f'{key}: existing task, no duplicate submission')
            continue
        entry = {'fingerprint': fingerprint, 'status': 'SUBMITTING', 'job_id': None}
        state[key] = entry
        save(state_path, state)
        try:
            result = api('SubmitHunyuanTo3DProJob', payload)
            if not result.get('JobId'):
                raise RuntimeError('Response contains no JobId; inspect API Inspector.')
            entry.update(job_id=result['JobId'], status='WAIT', request_id=result.get('RequestId'))
        except Exception:
            entry['status'] = 'SUBMISSION_UNRESOLVED'
            save(state_path, state)
            raise
        save(state_path, state)
        print(f'{key}: submitted JobId={entry["job_id"]}')


def poll(state, state_path=STATE):
    pending = False
    for key, entry in state.items():
        if entry['status'] == 'DOWNLOADED':
            target = ROOT / entry['file']
            if target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == entry['summary']['sha256']:
                continue
            # Restore a missing/corrupt local download using the SAME cloud task.
            entry['status'] = 'DONE'
        if not entry.get('job_id'):
            raise RuntimeError(f'{key}: unresolved submission; no automatic resubmission')
        result = api('QueryHunyuanTo3DProJob', {'JobId': entry['job_id']})
        status = result['Status']
        entry['status'] = status
        save(state_path, state)
        print(f'{key}: {status}')
        if status == 'FAIL':
            raise RuntimeError(f'{key}: generation failed ({result.get("ErrorCode", "Unknown")})')
        if status == 'DONE':
            files = [f for f in result.get('ResultFile3Ds', []) if f.get('Type', '').upper() == 'GLB']
            if not files:
                raise RuntimeError(f'{key}: no GLB returned; inspect this existing task')
            target = ROOT / 'assets/models/realistic/hunyuan_raw' / f'{key}.glb'
            summary = download_glb(files[0]['Url'], target)
            entry.update(status='DOWNLOADED', file=str(target.relative_to(ROOT)), summary=summary,
                         rigging_status='not_verified', modular_equipment_status='not_built')
            save(state_path, state)
            print(f'{key}: raw GLB downloaded, {summary["meshes"]} meshes; rigging/modularity NOT validated')
        elif status in ['WAIT', 'RUN']:
            pending = True
        else:
            raise RuntimeError(f'{key}: unrecognized status {status}')
    return pending


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['configure', 'plan', 'submit', 'poll', 'adopt'])
    parser.add_argument('--wait-seconds', type=int, default=0)
    parser.add_argument('--asset')
    parser.add_argument('--job-id')
    args = parser.parse_args()
    if args.command == 'configure':
        if not sys.stdin.isatty():
            raise RuntimeError('Run configure in your own interactive terminal; do not paste secrets into chat.')
        sid = getpass.getpass('Tencent Cloud SecretId (hidden): ').strip()
        key = getpass.getpass('Tencent Cloud SecretKey (hidden): ').strip()
        token = getpass.getpass('Session token if using temporary credentials (otherwise Enter): ').strip()
        if not sid or not key:
            raise ValueError('SecretId and SecretKey are required')
        STATE.parent.mkdir(parents=True, exist_ok=True)
        target = STATE.parent / 'credentials.json'
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w') as file:
            json.dump({'secret_id': sid, 'secret_key': key, 'session_token': token}, file)
        print('Credentials saved locally; no cloud tasks submitted.')
        return 0
    prepared = prepare(json.loads(CONFIG.read_text()))
    if args.command == 'plan':
        for item, payload, fingerprint in prepared:
            print(f'{item["id"]}: {item["gender"]}, {item["image"]}, Model={payload["Model"]}, FaceCount={payload["FaceCount"]}, PBR={payload["EnablePBR"]}, sha256={fingerprint[:12]}')
        try:
            credentials()
            ready = True
        except RuntimeError:
            ready = False
        print('Credentials: ' + ('configured' if ready else 'MISSING; generation not submitted'))
        return 0
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with STATE.with_suffix('.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another generation process owns this queue') from None
        state = json.loads(STATE.read_text()) if STATE.is_file() else {}
        if args.command == 'submit':
            submit(prepared, state)
        elif args.command == 'adopt':
            if args.asset not in state or not args.job_id or not re.fullmatch(r'[A-Za-z0-9_-]+', args.job_id):
                raise ValueError('adopt requires an existing unresolved --asset and a verified --job-id')
            if state[args.asset].get('job_id'):
                raise ValueError('This asset already has a JobId; refusing to overwrite')
            state[args.asset].update(job_id=args.job_id, status='WAIT')
            save(STATE, state)
        else:
            if not state:
                raise RuntimeError('No jobs submitted')
            deadline = time.monotonic() + max(0, args.wait_seconds)
            while poll(state):
                if time.monotonic() >= deadline:
                    print('Tasks pending; poll again to resume')
                    return 2
                time.sleep(min(20, max(0, deadline - time.monotonic())))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError) as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(1)
