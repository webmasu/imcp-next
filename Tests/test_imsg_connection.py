import importlib.machinery
import importlib.util
import json
import os
from unittest import mock
from pathlib import Path
import subprocess
import sys
import unittest
import tempfile

script = Path(__file__).resolve().parents[1] / "Scripts/imsg/imcp-imsg"
loader = importlib.machinery.SourceFileLoader("imcp_imsg", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
imsg = importlib.util.module_from_spec(spec)
loader.exec_module(imsg)


class ImsgConnectionTests(unittest.TestCase):
    def test_wrapper_routing(self):
        for method in imsg.METHODS:
            for mode in ("imsg-vm", "lume"):
                argv = imsg.command(mode, "", method)
                self.assertEqual(Path(argv[0]).name, "imsg-vm")
                self.assertEqual(argv[1:], ["imsg" if method == "send" else "imsg-ro", "rpc"])

    def test_local_executable_is_used_for_reads_and_writes(self):
        with tempfile.TemporaryDirectory(prefix="local imsg ") as directory:
            binary = Path(directory) / "imsg"
            binary.touch(mode=0o700)
            for method in imsg.METHODS:
                self.assertEqual(imsg.command("local", str(binary), method), [str(binary), "rpc"])
            for path in ["relative/imsg", str(binary) + " missing"]:
                with self.assertRaises(ValueError):
                    imsg.command("local", path, "status")

    def test_ssh_uses_a_fixed_remote_command(self):
        self.assertEqual(imsg.command("ssh", "messages-vm", "send")[-3:],
                         ["--", "messages-vm", "/usr/local/bin/imsg rpc"])
        for host in ("-F", "invalid alias", "vm\n", ""):
            with self.assertRaises(ValueError):
                imsg.command("ssh", host, "status")

    def test_params_cannot_trigger_other_actions(self):
        for method, params in [
            ("read", {}), ("send", {"to": "a", "file": []}),
            ("send", {"chat_id": 2, "to": "a", "text": "test"}),
            ("send", {"to": "x", "text": {"path": "/tmp/test"}}),
            ("messages.history", {}), ("chats.list", {"limit": True}),
            ("messages.search", {"limit": 101, "query": "a"}),
        ]:
            with self.assertRaises(ValueError):
                imsg.validate({"method": method, "params": params})

    def test_catalog_binds_native_methods_and_preserves_cli_values(self):
        ops = imsg.imsg_operations
        catalog = json.loads((script.parents[2] / "App/Services/imsg-tools.json").read_text())
        with mock.patch.object(ops, "catalog", return_value=catalog):
            with self.assertRaises(ValueError):
                ops.execute("account", {"native_params": {"method":"send"}}, "ssh", "vm", imsg.command, None, None)
            rpc = mock.Mock()
            ops.execute("after", {"native_params":{"since_rowid":10}}, "imsg-vm", "", imsg.command, rpc, None)
            argv, request = rpc.call_args.args
            self.assertEqual(argv[-2:], ["imsg-ro", "rpc"])
            self.assertEqual(request["method"], "messages.after")
            capture = mock.Mock(return_value=b'{"ok":true}')
            ops.execute("poll_send", {"chat":"test", "option":["-a","b"], "question":"a b"}, "local",
                        "/test", lambda *_: ["/test/imsg","rpc"], None, capture)
            self.assertIn("--question=a b", capture.call_args.args[0])
            self.assertIn("--option=-a", capture.call_args.args[0])

    def test_attachment_export_checks_directory_and_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            folder = home / "Library/Messages/Attachments"
            folder.mkdir(parents=True)
            sample = folder / "image.png"
            sample.write_bytes(b"sample")
            (folder / "alias").symlink_to(sample)
            for path, ok in [(sample, True), (folder/"alias", False), (folder/".."/"Attachments"/"image.png", False)]:
                child = subprocess.run([sys.executable, str(script.with_name("imsg_attachment.py"))],
                                       input=json.dumps(str(path)).encode(), capture_output=True,
                                       env={**os.environ,"HOME":tmp})
                self.assertEqual(child.returncode == 0, ok)
                if ok:
                    self.assertEqual(child.stdout, b"sample")

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
