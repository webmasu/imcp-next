import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

script = Path(__file__).resolve().parents[1] / "Scripts/imsg/imcp-imsg"
loader = importlib.machinery.SourceFileLoader("imcp_imsg", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
imsg = importlib.util.module_from_spec(spec)
loader.exec_module(imsg)


class ImsgConnectionTests(unittest.TestCase):
    def test_wrapper_routing(self):
        for method in imsg.METHODS:
            argv = imsg.command("lume", "", method)
            self.assertEqual(Path(argv[0]).name, "imsg-rw" if method == "send" else "imsg-ro")
            self.assertEqual(argv[1:], ["rpc"])

    def test_ssh_uses_a_fixed_remote_command(self):
        self.assertEqual(imsg.command("ssh", "messages-vm", "send")[-3:],
                         ["--", "messages-vm", "/usr/local/bin/imsg rpc"])
        for host in ("-F", "invalid alias", "vm\n", ""):
            with self.assertRaises(ValueError):
                imsg.command("ssh", host, "status")

    def test_params_cannot_trigger_other_actions(self):
        for method, params in [
            ("read", {}), ("send", {"to": "a", "file": "/tmp/a"}),
            ("send", {"chat_id": 2, "to": "a", "text": "test"}),
            ("send", {"to": "x", "text": {"path": "/tmp/test"}}),
            ("messages.history", {}), ("chats.list", {"limit": True}),
            ("messages.search", {"limit": 101, "query": "a"}),
        ]:
            with self.assertRaises(ValueError):
                imsg.validate({"method": method, "params": params})

    def test_send_round_trip_uses_only_a_fake_child(self):
        params = {"to": "test@example.invalid", "text": 'a\n"b" ' * 1800}
        request = imsg.validate({"method": "send", "params": params})
        child = ("import sys,json; r=json.load(sys.stdin); "
                 "print(json.dumps(dict(jsonrpc='2.0',id=r['id'],result=r['params'])))")
        self.assertEqual(imsg.exchange([sys.executable, "-c", child], request), {"result": params})

    def test_rpc_error_keeps_retry_information(self):
        error = {"message": "uncertain", "data": {"retry_safe": False}}
        response = json.dumps({"jsonrpc": "2.0", "id": 1, "error": error})
        self.assertEqual(imsg.exchange(["/bin/echo", response], {}), {"error": error})

    def test_timeout_stops_a_child_that_never_reads(self):
        with self.assertRaises((TimeoutError, subprocess.TimeoutExpired)):
            imsg.exchange(["/bin/sleep", "20"], {"input": "x" * 60000}, timeout=0.15)

    def test_wrong_id_and_oversized_response_fail(self):
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            imsg.exchange(["/bin/echo", '{"jsonrpc":"2.0","id":true,"result":{}}'], {})
        with self.assertRaisesRegex(ValueError, "exceeded"):
            imsg.exchange([sys.executable, "-c", "print('x'*9000000)"], {})


if __name__ == "__main__":
    unittest.main()
