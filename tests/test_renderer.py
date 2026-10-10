import os
import re
import subprocess
import sys
import unittest
import unicodedata
from pathlib import Path

FILE = Path(__file__).resolve().parents[1] / "vesly"
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def render(cols, rows=24, extra=()):
    env = {**os.environ, "COLUMNS": str(cols), "LINES": str(rows)}
    result = subprocess.run([sys.executable, str(FILE), "--plain", "--no-clear", *extra],
                            text=True, capture_output=True, check=True, env=env, timeout=20)
    return ANSI.sub("", result.stdout)


class RendererTest(unittest.TestCase):
    def test_terminal_sizes(self):
        for cols, rows in [(140, 24), (140, 30), (120, 24), (112, 24),
                           (100, 24), (99, 24), (98, 24), (80, 24), (60, 24)]:
            with self.subTest(cols=cols, rows=rows):
                data = render(cols, rows)
                lines = data.splitlines()
                width = max(sum(2 if unicodedata.east_asian_width(c) in "FW" else 1
                                for c in line) for line in lines)
                self.assertLessEqual(width, cols)
                self.assertLessEqual(len(lines), rows - 1)
                self.assertIn("Vesly Cloud Labs", data)
                self.assertIn("Private Cloud", data)
                self.assertIn("security@vesly.dev", data)
                self.assertIn("Memory", data)
                self.assertIn("Tailscale", data)
                self.assertNotIn(" ·  ready", data)
                self.assertNotIn(" / dev", data)

    def test_wide_logo_on_24_row_tty(self):
        for cols in [99, 100, 112, 140]:
            with self.subTest(cols=cols):
                self.assertIn("⣾⣿⣿⣿⣶⣷", render(cols, 24))

    def test_full_and_ansi(self):
        self.assertIn("Vesly Cloud Labs", render(140, 50, ("--full",)))
        env = {**os.environ, "COLUMNS": "100", "LINES": "24"}
        r = subprocess.run([sys.executable, str(FILE), "--color", "--no-clear"],
                           capture_output=True, check=True, env=env, timeout=20)
        self.assertIn(b"\x1b[38;2;125;66;246m", r.stdout)
        self.assertIn(b"\x1b[38;2;209;156;255m", r.stdout)


if __name__ == "__main__":
    unittest.main()
