// Lambda (Function URL) that serves the dashboard page and its API.
// Data endpoints require the shared access code (header x-access-code).
import fs from "fs";
import { S3Client, ListObjectsV2Command, DeleteObjectCommand, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const BUCKETS = {
  A: { name: process.env.BUCKET_A, region: process.env.REGION_A },
  B: { name: process.env.BUCKET_B, region: process.env.REGION_B },
};
const clients = Object.fromEntries(Object.entries(BUCKETS).map(([k, b]) => [k, new S3Client({ region: b.region })]));
const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");

const reply = (code, body, type = "application/json") => ({
  statusCode: code,
  headers: { "content-type": type, "cache-control": "no-store" },
  body: typeof body === "string" ? body : JSON.stringify(body),
});

async function listSide(side) {
  try {
    const objects = [];
    let token;
    do {
      const r = await clients[side].send(new ListObjectsV2Command({ Bucket: BUCKETS[side].name, ContinuationToken: token }));
      (r.Contents || []).forEach(o => objects.push({ key: o.Key, size: o.Size, modified: o.LastModified }));
      token = r.NextContinuationToken;
    } while (token);
    return { ...BUCKETS[side], up: true, objects };
  } catch (e) {
    return { ...BUCKETS[side], up: false, objects: [], error: e.name };
  }
}

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.rawPath;
  if (method === "GET" && (path === "/" || path === "/index.html")) return reply(200, html, "text/html; charset=utf-8");

  const code = event.headers?.["x-access-code"];
  if (!process.env.ACCESS_CODE || code !== process.env.ACCESS_CODE) return reply(401, { error: "bad access code" });

  const q = event.queryStringParameters || {};
  const side = q.side, key = q.key;
  try {
    if (path === "/api/state") {
      const [A, B] = await Promise.all([listSide("A"), listSide("B")]);
      return reply(200, { A, B });
    }
    if (!BUCKETS[side] || !key) return reply(400, { error: "bad request" });
    const Bucket = BUCKETS[side].name;
    if (path === "/api/upload-url") {
      const type = q.type || "application/octet-stream";
      const url = await getSignedUrl(clients[side], new PutObjectCommand({ Bucket, Key: key, ContentType: type }), { expiresIn: 300 });
      return reply(200, { url, type });
    }
    if (path === "/api/download-url") {
      const url = await getSignedUrl(clients[side], new GetObjectCommand({
        Bucket, Key: key,
        ResponseContentDisposition: `attachment; filename*=UTF-8''${encodeURIComponent(key.split("/").pop())}`,
      }), { expiresIn: 120 });
      return reply(200, { url });
    }
    if (path === "/api/delete" && method === "POST") {
      await clients[side].send(new DeleteObjectCommand({ Bucket, Key: key }));
      return reply(200, { ok: true });
    }
    return reply(404, { error: "not found" });
  } catch (e) {
    return reply(500, { error: e.message });
  }
};
