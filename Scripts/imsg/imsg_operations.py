"""Run the published imsg operations on the selected Mac."""
import json
from pathlib import Path
import shlex
import tempfile

HERE = Path(__file__).resolve().parent


def catalog():
    return json.loads((HERE / "imsg-tools.json").read_text())


def cli_arguments(spec, params, fields):
    args = spec["route"].split()
    for key, value in params.items():
        if key == "seconds":
            continue
        option = "--" + key.replace("_", "-")
        kind = fields[key][0]
        if kind == "boolean":
            if value:
                args.append(option)
        else:
            for item in value if kind == "array" else [value]:
                # One token per value, including leading hyphens and embedded spaces.
                args.append(f"{option}={item}")
    return args + ["--json"]


def validate(spec, params, fields):
    if not isinstance(params, dict) or params.keys() - set(spec["fields"]):
        raise ValueError("Unknown imsg parameter")
    if set(spec.get("required", ())) - params.keys():
        raise ValueError("Missing required imsg parameter")
    for key, val in params.items():
        kind = fields[key][0]
        valid = {"string": isinstance(val, str) and bool(val.strip()) and "\x00" not in val,
                 "integer": type(val) is int, "number": type(val) in (float, int),
                 "boolean": type(val) is bool,
                 "array": isinstance(val, list) and all(isinstance(v, str) and v and "\x00" not in v for v in val)}
        if not valid[kind]:
            raise ValueError(f"Invalid {key}")
    if "seconds" in params and not 1 <= params["seconds"] <= 30:
        raise ValueError("Use an observation window of 1 to 30 seconds")
    if "limit" in params and not 1 <= params["limit"] <= (500 if spec["route"] == "rpc:messages.after" else 100):
        raise ValueError("Invalid page size")


def invocation(rpc_argv, mode, args):
    if mode != "ssh":
        return rpc_argv[:-1] + args
    return rpc_argv[:-1] + [shlex.join(["/usr/local/bin/imsg", *args])]


def attachment(mode, target, path, command, capture):
    # Only this fixed reader runs remotely. The requested path travels on stdin.
    reader = (HERE / "imsg_attachment.py").read_text()
    argv = ["/usr/bin/python3", "-c", reader]
    if mode in ("lume", "imsg-vm"):
        argv = [str(Path.home() / ".local/bin/imsg-vm"), "ssh", shlex.join(argv)]
    elif mode == "ssh":
        argv = command(mode, target, "status")[:-1] + [shlex.join(argv)]
    elif mode != "local":
        raise ValueError("Unknown imsg mode")
    data = capture(argv, json.dumps(path).encode(), timeout=60, maximum=64*1024*1024)
    folder = Path(tempfile.mkdtemp(prefix="imcp-attachment-"))
    output = folder / Path(path).name
    try:
        with output.open("xb") as fp:
            fp.write(data)
    except BaseException:
        output.unlink(missing_ok=True)
        folder.rmdir()
        raise
    return {"result": {"path": str(output), "bytes": len(data)}}


def execute(name, params, mode, target, command, exchange, capture):
    definitions = catalog()
    spec = definitions["tools"].get(name)
    if spec is None:
        raise ValueError("Unknown imsg operation")
    route = spec["route"]
    params = params.copy()
    native = params.pop("native_params", None)
    subscribing = spec.get("rpc") in ("watch.subscribe", "bridge.events.subscribe")
    seconds = params.pop("seconds", 5) if subscribing else None
    if subscribing and (type(seconds) is not int or not 1 <= seconds <= 30):
        raise ValueError("Use an observation window of 1 to 30 seconds")
    if native is not None:
        if not spec.get("rpc") or not isinstance(native, dict) or params:
            raise ValueError("Use native_params alone, with optional seconds for subscriptions")
        params, route = native, "rpc:" + spec["rpc"]
    else:
        validate(spec, params, definitions["fields"])
    if route == "attachment":
        return attachment(mode, target, params["path"], command, capture)
    # The wrapper authorizes each read again. Write commands use its standard imsg entry point.
    base = command(mode, target, "status" if spec["read"] else "send")
    if route == "completions":
        shell = params["shell"]
        if shell not in ("bash", "zsh", "fish"):
            raise ValueError("Use bash, zsh or fish")
        data = capture(invocation(base, mode, ["completions", shell]), b"")
        return {"result": {"shell": shell, "text": data.decode()}}
    if route.startswith("rpc:"):
        request = {"jsonrpc": "2.0", "id": 1, "method": route[4:], "params": params}
        if not subscribing:
            return exchange(base, request)
        raw = capture(base, json.dumps(request).encode() + b"\n", timeout=seconds, window=True, hold_input=True)
        events = []
        ack = None
        for line in raw.splitlines():
            record = json.loads(line)
            if record.get("id") == 1:
                if "error" in record:
                    return {"error": record["error"]}
                ack = record.get("result")
            elif "method" in record:
                events.append(record)
        if ack is None:
            raise ValueError("imsg did not acknowledge the subscription within the observation window")
        return {"result": {"events": events, "subscription": ack, "closed": True}}
    args = cli_arguments(spec, params, definitions["fields"])
    watching = route == "watch"
    output = capture(invocation(base, mode, args), b"", timeout=seconds if watching else 60,
                     window=watching)
    if not watching and output.strip():
        try:
            return {"result": json.loads(output)}
        except json.JSONDecodeError:
            pass  # Some imsg commands emit multiple JSON lines.
    records = [json.loads(line) for line in output.splitlines() if line.strip()]
    return {"result": records[0] if len(records) == 1 and not watching else records}
