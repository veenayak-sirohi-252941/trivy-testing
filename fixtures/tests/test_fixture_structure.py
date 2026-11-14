import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class FixtureStructureTests(unittest.TestCase):
  def test_expected_project_paths_exist(self):
    required = ['README.md', '.gitleaks.toml', 'src', 'config', 'aws', 'github', 'database', 'api', 'infra/terraform', 'k8s', 'scripts', 'docs', 'tests/fixtures/positive', 'tests/fixtures/negative']
    self.assertTrue(all((ROOT / p).exists() for p in required))

  def test_fixture_catalog_is_unique_and_valid(self):
    items = json.loads((ROOT / 'tests/fixtures/positive/fixture_catalog.json').read_text())
    ids = [x['id'] for x in items]
    self.assertEqual(len(ids), len(set(ids)))
    self.assertTrue(all((ROOT / x['path']).is_file() for x in items))
