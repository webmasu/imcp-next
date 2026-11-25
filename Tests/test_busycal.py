import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
from unittest import TestCase, mock


script = Path(__file__).resolve().parents[1] / "Scripts/busycal/imcp-busycal"
loader = importlib.machinery.SourceFileLoader("imcp_busycal", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
busycal = importlib.util.module_from_spec(spec)
loader.exec_module(busycal)


class BusyCalTests(TestCase):
    def bridge(self, replies):
        process = mock.MagicMock()
        process.stdout = io.BytesIO(b"".join(json.dumps(r).encode() + b"\n" for r in replies))
        factory = mock.patch.object(busycal.subprocess, "Popen", return_value=process)
        factory.start()
        self.addCleanup(factory.stop)
        return process

    @staticmethod
    def hello():
        return {"id": 1, "result": {"protocolVersion": busycal.PROTOCOL, "capabilities": {"tools": {}}}}

    def test_catalog_follows_cursor_and_skips_notifications(self):
        process = self.bridge([self.hello(), {"method": "notifications/tools/list_changed"},
                               {"id": 2, "result": {"tools": [{"name": "read"}], "nextCursor": "next"}},
                               {"id": 3, "result": {"tools": [{"name": "write"}]}}])
        self.assertEqual(busycal.run(script, None), [{"name": "read"}, {"name": "write"}])
        sent = [json.loads(call.args[0]) for call in process.stdin.write.call_args_list]
        self.assertEqual([s["method"] for s in sent], ["initialize", "notifications/initialized", "tools/list", "tools/list"])
        self.assertEqual(sent[-1]["params"], {"cursor": "next"})

    def test_lost_response_does_not_replay_change(self):
        process = self.bridge([self.hello()])
        with self.assertRaisesRegex(RuntimeError, "closed"):
            busycal.run(script, {"name": "create_event", "arguments": {"title": "fixture"}})
        methods = [json.loads(call.args[0])["method"] for call in process.stdin.write.call_args_list]
        self.assertEqual(methods.count("tools/call"), 1)
