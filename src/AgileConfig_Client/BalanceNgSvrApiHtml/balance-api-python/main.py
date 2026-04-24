"""Balance demo API — same contract as BalanceNgSvrApi (C#)."""
import os
import socket
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="balance-api-python")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict:
    return {
        "ok": True,
        "utc": datetime.now(timezone.utc).isoformat(),
        "machine": socket.gethostname(),
    }


@app.post("/api/submit")
async def submit(
    request: Request,
    name: str = Form(...),
    remark: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
):
    ct = request.headers.get("content-type", "")
    if "multipart/form-data" not in ct:
        return JSONResponse(
            status_code=400,
            content={"error": "Content-Type 须为 multipart/form-data"},
        )
    if not name or not name.strip():
        return JSONResponse(status_code=400, content={"error": "name 必填"})
    saved = None
    size = None
    if file and file.filename:
        raw = await file.read()
        if raw:
            safe = Path(file.filename).name or "upload.bin"
            # align with C# DateTime.UtcNow: yyyyMMddHHmmssfff (fff = ms)
            now = datetime.now(timezone.utc)
            stamp = now.strftime("%Y%m%d%H%M%S") + f"{now.microsecond // 1000:03d}"
            dest = UPLOAD_DIR / f"{stamp}_{safe}"
            dest.write_bytes(raw)
            saved = dest.name
            size = dest.stat().st_size
    return {
        "message": "已处理",
        "name": name,
        "remark": remark if remark is not None else "",
        "file": saved,
        "bytes": size,
    }


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "5091"))
    uvicorn.run(app, host="127.0.0.1", port=port)
