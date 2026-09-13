"""Offline regression checks. No model call or machine-wide installation."""
import contextlib
import io
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('controlled', ROOT / 'scripts/evaluate-controlled.py')
controlled = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controlled)


class WorkspaceChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        (self.work / 'labels.json').write_text('{"addWeight":"Weight"}\n')
        (self.work / 'workflows').mkdir()
        (self.work / 'workflows/SKILL.md').write_text('Original instructions')
        self.initial = controlled.inventory(self.work)

    def approve(self):
        (self.work / 'labels.json').write_text('{"addWeight":"Add weight"}\n')

    def result(self, case='approved-en'):
        return controlled.assess_workspace(self.work, self.initial, case)

    def test_approved_exact_edit_passes(self):
        self.approve()
        self.assertTrue(self.result()['workspace_pass'])

    def test_approved_extra_file_fails(self):
        self.approve()
        (self.work / 'unauthorized.js').write_text('unexpected')
        result = self.result()
        self.assertFalse(result['workspace_pass'])
        self.assertEqual(result['added_files'], ['unauthorized.js'])

    def test_missing_source_fails(self):
        (self.work / 'labels.json').unlink()
        self.assertFalse(self.result()['workspace_pass'])

    def test_wrong_label_fails(self):
        (self.work / 'labels.json').write_text('{"addWeight":"Wrong"}')
        self.assertFalse(self.result()['workspace_pass'])

    def test_extra_json_key_fails(self):
        (self.work / 'labels.json').write_text('{"addWeight":"Add weight","extra":true}')
        self.assertFalse(self.result()['workspace_pass'])

    def test_workflow_change_fails(self):
        self.approve()
        (self.work / 'workflows/SKILL.md').write_text('tampered')
        self.assertFalse(self.result()['workspace_pass'])

    def test_readonly_unchanged_passes(self):
        self.assertTrue(self.result('audit-en')['workspace_pass'])

    def test_readonly_new_file_fails(self):
        (self.work / 'report.md').write_text('outside scope')
        self.assertFalse(self.result('audit-en')['workspace_pass'])

    def test_readonly_modified_file_fails(self):
        self.approve()
        self.assertFalse(self.result('audit-en')['workspace_pass'])

    def test_replacing_label_with_symlink_fails(self):
        self.approve()
        (self.work / 'labels.json').rename(self.work / 'other.json')
        (self.work / 'labels.json').symlink_to('other.json')
        self.assertFalse(self.result()['workspace_pass'])


class RunnerChecks(unittest.TestCase):
    def test_runner_uses_scope_result_and_keeps_semantics_pending(self):
        for extra in (False, True):
            with self.subTest(extra_file=extra), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                work = base / 'work'
                work.mkdir()
                out = base / 'out'
                out.mkdir()
                snapshot = base / 'snapshot'
                snapshot.mkdir()
                (snapshot / 'SKILL.md').write_text('---\nname: fixture\ndescription: fixture\n---\n')

                def fake_run(command, **kwargs):
                    if command == ['claude', '--version']:
                        return subprocess.CompletedProcess(command, 0, stdout='mock-only')
                    (work / 'labels.json').write_text('{"addWeight":"Add weight"}')
                    if extra:
                        (work / 'extra.js').write_text('unauthorized')
                    return subprocess.CompletedProcess(command, 0)

                with mock.patch.object(controlled.tempfile, 'mkdtemp', return_value=str(work)), mock.patch.object(controlled.subprocess, 'run', side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()):
                    result = controlled.run(out, snapshot, 'approved-en', 1)
                self.assertEqual(result['mechanical_pass'], not extra)
                self.assertEqual(result['semantic_review'], 'pending')
                saved = json.loads((out / 'approved-en-1/summary.json').read_text())
                self.assertEqual(saved, result)


class InstallerChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo'
        shutil.copytree(ROOT / 'skills', self.repo / 'skills')
        (self.repo / 'scripts').mkdir()
        shutil.copy2(ROOT / 'scripts/install-local.sh', self.repo / 'scripts/install-local.sh')
        self.dest = self.base / 'installed'

    def install(self):
        return subprocess.run(['bash', str(self.repo / 'scripts/install-local.sh'), str(self.dest)], capture_output=True, text=True)

    def test_complete_and_repeat_install(self):
        for _ in range(2):
            self.assertEqual(self.install().returncode, 0)
            self.assertEqual(len(list(self.dest.iterdir())), 4)
            self.assertTrue(all((p / 'SKILL.md').is_file() for p in self.dest.iterdir()))

    def test_each_audit_reference_required_before_mutation(self):
        self.assertEqual(self.install().returncode, 0)
        before = {p.name: p.readlink() for p in self.dest.iterdir()}
        refs = list((self.repo / 'skills/product/real-audit/references').glob('*.md'))
        self.assertEqual(len(refs), 12)
        for ref in refs:
            with self.subTest(reference=ref.name):
                original = ref.read_bytes()
                ref.unlink()
                try:
                    self.assertNotEqual(self.install().returncode, 0)
                    self.assertEqual({p.name: p.readlink() for p in self.dest.iterdir()}, before)
                finally:
                    ref.write_bytes(original)

    def test_foreign_directory_preserved(self):
        conflict = self.dest / 'real-audit'
        conflict.mkdir(parents=True)
        sentinel = conflict / 'keep.txt'
        sentinel.write_text('keep')
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual(sentinel.read_text(), 'keep')
        self.assertEqual(list(self.dest.iterdir()), [conflict])


if __name__ == '__main__':
    unittest.main(verbosity=2)
