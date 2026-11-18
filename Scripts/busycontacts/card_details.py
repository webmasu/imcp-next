"""Read supplemental vCard data and cached photos from BusyContacts."""
import base64
from pathlib import Path
import plistlib
import re
from urllib.parse import urlsplit

MAX_PHOTO = 5 * 1024 * 1024


def archived_value(blob):
    # Decode the small Foundation string/array archives used for notes and tags.
    if not blob:
        return None
    archive = plistlib.loads(blob.removeprefix(b"\x01"))
    objects = archive["$objects"]

    def decode(ref, depth=0):
        if depth > 4:
            raise ValueError("Unsupported nested BusyContacts archive")
        value = objects[ref.data]
        if isinstance(value, str):
            return value
        if "NSString" in value:
            return decode(value["NSString"], depth + 1)
        return [decode(entry, depth + 1) for entry in value["NS.objects"]]

    return decode(archive["$top"]["root"])


def supplemental(db, card_id):
    row = db.execute("SELECT ZCONTENT, ZTAGS FROM ZCOMMONDATA WHERE Z_PK=?", (card_id,)).fetchone()
    note, tags = [archived_value(v) for v in row]
    if note is not None and not isinstance(note, str):
        raise ValueError("Unsupported note format")
    if tags and not (isinstance(tags, list) and all(isinstance(t, str) for t in tags)):
        raise ValueError("Unsupported tag format")
    fields, extensions = [], []
    for field in db.execute("""
            SELECT f.ZFIELDTYPE type, f.ZFIELDLABELTYPE labelType, f.ZFIELDLABEL label,
                   f.ZFIELDPREF preferred, f.ZFIELDSTRING value, f.ZFIELDDICT attributes
            FROM ZEXTRADATA f JOIN Z_PRIMARYKEY e ON e.Z_ENT=f.Z_ENT AND e.Z_NAME='FieldData'
            WHERE f.ZPARENTOBJECT=? ORDER BY f.ZFIELDSORT,f.Z_PK""", (card_id,)):
        fields.append({key: value for key, value in dict(field).items() if value is not None})
        if field["type"] == 300 and field["value"] is not None:
            match = re.search(r'"propName"\s*=\s*"([A-Za-z0-9-]+)"', field["attributes"] or "")
            if match:
                extensions.append({"name": match[1], "value": field["value"]})
    return {"note": note or "", "tags": tags or [], "extensions": extensions, "busyFields": fields}


def cached_photo(db, card_id, directory, include_bytes):
    row = db.execute("""
        SELECT ZFILENAME,ZFILEURL,ZUID,Z_OPT FROM ZFILEATTACHMENTEXTRA
        WHERE ZPARENTOBJECT=? AND ZATTACHMENTTYPE=1 ORDER BY Z_PK""", (card_id,)).fetchall()
    if not row:
        return {}, None
    if len(row) != 1:
        raise ValueError("Multiple BusyContacts photos on this card")
    filename, url, uid, version = row[0]
    if filename and uid:
        name = Path(filename)
        candidate = f"{name.stem}-{uid}{name.suffix}"
    elif url:
        parts = urlsplit(url)
        candidate = parts.netloc + parts.path.replace("/", "-")
    else:
        candidate = ""
    result = {"hasBusyPhoto": True}
    if candidate and Path(candidate).name == candidate:
        path = directory / candidate
        if not path.is_symlink() and path.is_file():
            stat = path.stat()
            if include_bytes:
                if stat.st_size > MAX_PHOTO:
                    raise ValueError("BusyContacts photo exceeds 5 MiB. Use includePhoto=false to read the card.")
                with path.open("rb") as fp:
                    data = fp.read(MAX_PHOTO + 1)
                if len(data) != stat.st_size:
                    raise ValueError("Photo changed during the read. Read the card again.")
                result["photo"] = base64.b64encode(data).decode("ascii")
            return result, [uid, version, stat.st_mtime_ns, stat.st_size]
    return result, [uid, version]
