"""Exercise update promotion without accessing GitHub or publishing releases."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class UpdatePublicationTests(unittest.TestCase):
    def run_publication(self, *, tip="current", existing=True, fail_download=False):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            gh = folder / "gh"
            gh.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['CALL_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args[0] == 'api':
    print(os.environ['TIP'])
elif args[:2] == ['release', 'view']:
    sys.exit(0 if os.environ['EXISTING'] == '1' else 1)
elif args[:2] == ['release', 'download']:
    if os.environ['FAIL_DOWNLOAD'] == '1': sys.exit(1)
    (pathlib.Path(args[args.index('--dir') + 1]) / 'appcast.xml').write_text('<rss/>')
""")
            gh.chmod(0o755)
            log = folder / "calls.jsonl"
            result = subprocess.run(
                ["bash", str(ROOT / ".github/scripts/publish-update.sh")],
                env={**os.environ, "PATH": f"{folder}:{os.environ['PATH']}",
                     "GH_REPO": "example/luma-trail", "GITHUB_SHA": "current",
                     "RELEASE_TAG": "v0.5.0-abcdef0", "TIP": tip,
                     "EXISTING": str(int(existing)),
                     "FAIL_DOWNLOAD": str(int(fail_download)), "CALL_LOG": str(log)},
                capture_output=True, text=True,
            )
            return result.returncode, [json.loads(line) for line in log.read_text().splitlines()]

    def test_old_commit_cannot_replace_feed(self):
        code, calls = self.run_publication(tip="newer")
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)

    def test_first_release_creates_stable_feed(self):
        code, calls = self.run_publication(existing=False)
        self.assertEqual(code, 0)
        creation = next(call for call in calls if call[:2] == ["release", "create"])
        self.assertEqual(creation[2], "updates")
        self.assertIn("--latest=false", creation)
        self.assertEqual(calls[-1], ["release", "edit", "v0.5.0-abcdef0", "--latest"])

    def test_existing_feed_is_updated_before_latest(self):
        code, calls = self.run_publication()
        self.assertEqual(code, 0)
        self.assertEqual(calls[-2][:3], ["release", "upload", "updates"])
        self.assertEqual(calls[-1][:2], ["release", "edit"])

    def test_missing_signed_feed_prevents_promotion(self):
        code, calls = self.run_publication(fail_download=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(any(call[1] in ("create", "upload", "edit") for call in calls if call[0] == "release"))


if __name__ == "__main__":
    unittest.main()
