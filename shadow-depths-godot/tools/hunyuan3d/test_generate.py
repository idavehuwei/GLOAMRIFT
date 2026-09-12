import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import generate as g


def glb():
    data = json.dumps({'asset': {'version': '2.0'}, 'meshes': [{'primitives': []}]}).encode()
    data += b' ' * (-len(data) % 4)
    return struct.pack('<4sIIII', b'glTF', 2, 20 + len(data), len(data), 0x4E4F534A) + data


class GenerationTests(unittest.TestCase):
    def test_real_inputs_have_three_distinct_bodies(self):
        prepared = g.prepare(json.loads(g.CONFIG.read_text()))
        self.assertEqual([j[0]['gender'] for j in prepared], ['male', 'female', 'female'])
        self.assertEqual(len({j[2] for j in prepared}), 3)
        self.assertTrue(all('Prompt' not in j[1] and 'ImageBase64' in j[1] for j in prepared))

    def test_missing_auth_never_submits_or_records_intent(self):
        with tempfile.TemporaryDirectory() as directory:
            state = {}
            with patch.object(g, 'credentials', side_effect=RuntimeError('missing')), patch.object(g, 'api') as api:
                with self.assertRaises(RuntimeError):
                    g.submit([({'id': 'warrior'}, {}, 'hash')], state, Path(directory) / 'state.json')
                api.assert_not_called()
                self.assertEqual(state, {})

    def test_transport_failure_is_not_resubmitted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'state.json'
            state = {}
            prepared = [({'id': 'warrior'}, {}, 'hash')]
            with patch.object(g, 'credentials', return_value=('id', 'key', '')), patch.object(g, 'api', side_effect=RuntimeError('timeout')) as api:
                with self.assertRaises(RuntimeError):
                    g.submit(prepared, state, path)
                self.assertEqual(json.loads(path.read_text())['warrior']['status'], 'SUBMISSION_UNRESOLVED')
                with self.assertRaises(RuntimeError):
                    g.submit(prepared, state, path)
                self.assertEqual(api.call_count, 1)

    def test_resume_skips_existing_task_and_rejects_changed_input(self):
        state = {'mage': {'fingerprint': 'hash', 'status': 'RUN', 'job_id': '123'}}
        with patch.object(g, 'credentials', return_value=('id', 'key', '')), patch.object(g, 'api') as api:
            g.submit([({'id': 'mage'}, {}, 'hash')], state)
            with self.assertRaises(RuntimeError):
                g.submit([({'id': 'mage'}, {}, 'changed')], state)
            api.assert_not_called()

    def test_glb_rejects_error_pages_and_truncation(self):
        self.assertEqual(g.validate_glb(glb())['skins'], 0)
        for data in [b'<html>Error</html>', glb()[:-1]]:
            with self.assertRaises(ValueError):
                g.validate_glb(data)

    def test_pending_and_download_are_not_confused_with_rigged_model(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'state.json'
            state = {'archer': {'fingerprint': 'hash', 'job_id': '123', 'status': 'WAIT'}}
            with patch.object(g, 'api', return_value={'Status': 'RUN'}):
                self.assertTrue(g.poll(state, path))
            response = {'Status': 'DONE', 'ResultFile3Ds': [{'Type': 'GLB', 'Url': 'https://example.test/asset.glb'}]}
            with patch.object(g, 'api', return_value=response), patch.object(g, 'download_glb', return_value={'meshes': 1, 'skins': 0, 'sha256': 'hash'}):
                self.assertFalse(g.poll(state, path))
            self.assertEqual(state['archer']['status'], 'DOWNLOADED')
            self.assertEqual(state['archer']['rigging_status'], 'not_verified')
            self.assertEqual(state['archer']['modular_equipment_status'], 'not_built')

    def test_signature_changes_when_image_or_action_changes(self):
        args = ('fake-id', 'fake-secret', 'fake-session', 1700000000)
        a = g.signed_headers('SubmitHunyuanTo3DProJob', b'{}', *args)
        b = g.signed_headers('SubmitHunyuanTo3DProJob', b'{"changed":1}', *args)
        c = g.signed_headers('QueryHunyuanTo3DProJob', b'{}', *args)
        self.assertNotEqual(a['Authorization'], b['Authorization'])
        self.assertNotEqual(a['Authorization'], c['Authorization'])
        self.assertEqual(a['X-TC-Token'], 'fake-session')
        self.assertNotIn('fake-secret', str(a))
        self.assertEqual(a['X-TC-Version'], '2025-05-13')


if __name__ == '__main__':
    unittest.main()
