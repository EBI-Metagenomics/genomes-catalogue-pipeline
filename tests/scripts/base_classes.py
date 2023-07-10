import hashlib
import os
from pathlib import Path


class BaseTestWithFiles:
    def _get_checksum(self, filename):
        with open(filename, "r") as file_handle:
            file_content = "\n".join(sorted(file_handle.readlines()))
            return hashlib.md5(file_content.encode(encoding="UTF-8")).hexdigest()

    def _base_path(self):
        return Path(os.path.abspath("/" + os.path.dirname(__file__) + "/fixtures/"))
