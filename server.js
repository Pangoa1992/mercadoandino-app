const express = require("express");
const os = require("os");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

const app = express();
const s3 = new S3Client({ region: "us-east-1" }); // credenciales desde LabInstanceProfile

app.get("/", (req, res) => res.send("MercadoAndino v2 - instancia " + os.hostname()));
app.get("/health", (req, res) => res.status(200).send("ok"));

// Operacion 01.5: URL prefirmada (5 min) para que el vendedor suba su foto directo a S3
app.get("/api/upload-url", async (req, res) => {
  try {
    const type = req.query.type || "image/jpeg";
    if (!["image/jpeg", "image/png"].includes(type)) {
      return res.status(400).json({ error: "Solo se aceptan fotos JPG o PNG" });
    }
    const name = String(req.query.name || "foto.jpg").replace(/[^a-zA-Z0-9._-]/g, "_");
    const key = `uploads/${Date.now()}-${name}`;
    const cmd = new PutObjectCommand({ Bucket: process.env.BUCKET, Key: key, ContentType: type });
    const url = await getSignedUrl(s3, cmd, { expiresIn: 300 });
    res.json({ url, key });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(process.env.PORT || 80);
