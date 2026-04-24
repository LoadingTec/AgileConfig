import cors from "cors";
import express from "express";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import multer from "multer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadDir = path.join(__dirname, "uploads");
fs.mkdirSync(uploadDir, { recursive: true });

function utcFileStamp() {
  const d = new Date();
  const p2 = (n) => String(n).padStart(2, "0");
  const p3 = (n) => String(n).padStart(3, "0");
  return (
    `${d.getUTCFullYear()}${p2(d.getUTCMonth() + 1)}${p2(d.getUTCDate())}` +
    `${p2(d.getUTCHours())}${p2(d.getUTCMinutes())}${p2(d.getUTCSeconds())}` +
    p3(d.getUTCMilliseconds())
  );
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const safe = path.basename(file.originalname || "upload.bin") || "upload.bin";
    cb(null, `${utcFileStamp()}_${safe}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 },
});

const app = express();
app.use(cors({ origin: "*" }));

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    utc: new Date().toISOString(),
    machine: os.hostname(),
  });
});

app.post(
  "/api/submit",
  (req, res, next) => {
    const ct = req.headers["content-type"] || "";
    if (!ct.startsWith("multipart/form-data")) {
      return res.status(400).json({ error: "Content-Type 须为 multipart/form-data" });
    }
    next();
  },
  upload.single("file"),
  (req, res) => {
    const name = (req.body?.name ?? "").trim();
    if (!name) {
      return res.status(400).json({ error: "name 必填" });
    }
    const remark = req.body?.remark ?? "";
    const f = req.file;
    res.json({
      message: "已处理",
      name,
      remark,
      file: f ? f.filename : null,
      bytes: f ? f.size : null,
    });
  },
);

const port = Number(process.env.PORT || 5094);
app.listen(port, "127.0.0.1", () => {
  console.log(`balance-api-node listening on http://127.0.0.1:${port}`);
});
