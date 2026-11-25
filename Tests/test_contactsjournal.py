from pathlib import Path
import runpy
import sqlite3
import tempfile
import unittest

reader = runpy.run_path(str(Path(__file__).resolve().parents[1] / "Scripts/contactsjournal/imcp-contactsjournal"))["read"]


class JournalTests(unittest.TestCase):
    def test_contacts_shared_logs_followups_and_tombstones(self):
        with tempfile.TemporaryDirectory() as root:
            store = Path(root) / "fixture.sqlite"
            db = sqlite3.connect(store)
            db.executescript("""
                CREATE TABLE ZPERSON(Z_PK, ZDISPLAYNAME, ZCOMPANYNAME, ZISCONTACTARCHIVED, ZCLOUDKITREMOTELYDELETED);
                INSERT INTO ZPERSON VALUES (1,'Åsa','Bygg',0,0),(2,'Bo','Design',0,0),(3,'Deleted','Bygg',0,1);
                CREATE TABLE ZLOG(Z_PK,ZTITLE,ZLOGDATE,ZLOGNOTEMARKDOWNTEXT,ZLOGNOTE,ZLOGSUMMARYTEXT,
                                  ZPERSON,ZCLOUDKITREMOTELYDELETED);
                INSERT INTO ZLOG VALUES (6,1,0,NULL,'Meeting',NULL,2,0),(7,1,2,NULL,'Deleted',NULL,1,1);
                CREATE TABLE ZLOGTITLE(Z_PK,ZTITLE);
                INSERT INTO ZLOGTITLE VALUES(1,'Visit');
                CREATE TABLE Z_32MULTIPLEPEOPLE(Z_32MULTILOGS,Z_34MULTIPLEPEOPLE);
                INSERT INTO Z_32MULTIPLEPEOPLE VALUES (6,1),(6,2);
                CREATE TABLE ZTODO(Z_PK,ZTODOTITLE,ZTODOSTARTDATE,ZTODONOTEMARKDOWNTEXT,ZTODONOTE,ZTODOSUMMARYTEXT,
                                  ZPERSON,ZCLOUDKITREMOTELYDELETED,ZTODOSTATUS,ZTODOENDDATE,ZTODOCOMPLETEDDATE);
                INSERT INTO ZTODO VALUES(1,NULL,2,'Active',NULL,NULL,2,0,0,NULL,NULL),
                                        (2,NULL,1,NULL,'Done',NULL,1,0,1,NULL,90);
                CREATE TABLE ZTODOTITLE(Z_PK,ZTITLE);
                CREATE TABLE Z_34MULTITODOS(Z_46MULTITODOS,Z_34MULTIPLEPEOPLE1);
                INSERT INTO Z_34MULTITODOS VALUES(1,1);
            """)
            db.close()
            self.assertEqual([1], [x["id"] for x in reader(store, "contacts", {"query":"bygg"})["contacts"]])
            page = reader(store, "logs", {"contact_id": 1})["logs"]
            self.assertEqual([(x["title"], x["note"], x["date"]) for x in page],
                             [("Visit", "Meeting", "2001-01-01T00:00:00Z")])
            self.assertEqual([1], [r["id"] for r in reader(store, "todos", {"contact_id":1,"open_only":True})["todos"]])
            self.assertEqual(reader(store, "todos", {"contact_id":1,"limit":1})["nextOffset"], 1)
            with self.assertRaises(ValueError):
                reader(store, "logs", {"contact_id": 3})
