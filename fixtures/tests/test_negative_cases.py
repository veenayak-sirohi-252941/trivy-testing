from pathlib import Path
import unittest

NEG = Path(__file__).resolve().parent / 'fixtures/negative'

class NegativeFixtureTests(unittest.TestCase):
  def test_negative_placeholders_are_present(self):
    text = '\n'.join(p.read_text() for p in NEG.iterdir() if p.is_file())
    for marker in ('${AWS_ACCESS_KEY_ID}', '${AWS_SECRET_ACCESS_KEY}', '${DATABASE_URL}', 'YOUR_API_KEY_HERE', 'REPLACE_WITH_PASSWORD', '${GITHUB_TOKEN}', '${DB_PASSWORD}'):
        self.assertIn(marker, text)
