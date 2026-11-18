import importlib.machinery
import importlib.util
from pathlib import Path
import plistlib
import sqlite3
import tempfile
import unittest

source = Path(__file__).resolve().parents[1] / "Scripts/busycontacts/imcp-busycontacts"
loader = importlib.machinery.SourceFileLoader("busycontacts", str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
busy = importlib.util.module_from_spec(spec)
loader.exec_module(busy)


class BusyContactsTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.path = Path(root.name) / "BusyContacts.bsql"
        self.writer = sqlite3.connect(self.path)
        self.addCleanup(self.writer.close)
        self.writer.executescript("""
            PRAGMA journal_mode=WAL;
            PRAGMA wal_autocheckpoint=0;
            CREATE TABLE Z_PRIMARYKEY(Z_NAME, Z_ENT);
            INSERT INTO Z_PRIMARYKEY VALUES ('Contact',7),('Book',9),('FieldData',17);
            CREATE TABLE ZCOMMONDATA(Z_PK INTEGER PRIMARY KEY, Z_ENT, ZFIRSTNAME, ZMIDDLENAME, ZLASTNAME,
                       ZTITLE, ZLOCALTITLESEARCHTEXT, ZPARENTCONTAINERDIRECT);
            INSERT INTO ZCOMMONDATA VALUES(1,9,NULL,NULL,NULL,NULL,NULL,NULL),
                (2,7,NULL,NULL,NULL,NULL,NULL,1),(3,7,'Åsa',NULL,'Test',NULL,NULL,1),
                (4,7,'Åsa',NULL,'Test',NULL,NULL,1);
            CREATE TABLE ZEXTRADATA(Z_PK INTEGER PRIMARY KEY, Z_ENT, ZPARENTOBJECT, ZFIELDTYPE, ZFIELDSTRING, ZFIELDSORT);
            INSERT INTO ZEXTRADATA VALUES(10,17,3,18,'+46 (70) 123-4567',0),(11,17,3,4,'example@invalid.test',1);
        """)
        archive = {"$top": {"root": plistlib.UID(1)}, "$objects": ["$null", {"NSString": plistlib.UID(2)}, "Local book"]}
        self.writer.execute("UPDATE ZCOMMONDATA SET ZTITLE=? WHERE Z_PK=1",
                            (plistlib.dumps(archive, fmt=plistlib.FMT_BINARY),))
        self.writer.commit()

    def test_every_card_including_unnamed_and_duplicate_names(self):
        first = busy.read(self.path, {"limit": 2})
        self.assertEqual([row["id"] for row in first["contacts"]], [2, 3])
        self.assertEqual(first["contacts"][0]["addressBook"], "Local book")
        last = busy.read(self.path, {"limit": 2, "after": first["nextAfter"]})
        self.assertEqual([row["id"] for row in last["contacts"]], [4])
        self.assertIsNone(last["nextAfter"])

    def test_search_and_filtered_pagination(self):
        for query in ["46701234567", "EXAMPLE@INVALID", "A\u030asa"]:
            contacts = busy.read(self.path, {"query": query})["contacts"]
            self.assertEqual(contacts[0]["phones"], ["+46 (70) 123-4567"])
        first = busy.read(self.path, {"query": "åsa", "limit": 1})
        self.assertEqual(first["nextAfter"], 3)
        self.assertIsNone(busy.read(self.path, {"query": "åsa", "after": 3})["nextAfter"])
        self.assertEqual(busy.read(self.path, {"query": "%_"})["contacts"], [])

    def test_missing_database_is_not_created_and_invalid_input_fails(self):
        absent = self.path.with_name("absent")
        with self.assertRaises(sqlite3.Error):
            busy.read(absent, {})
        self.assertFalse(absent.exists())
        for args in ({"limit": 0}, {"after": True}, {"path": "other"}, {"query": 1}):
            with self.assertRaises(ValueError):
                busy.read(self.path, args)


if __name__ == "__main__":
    unittest.main()
