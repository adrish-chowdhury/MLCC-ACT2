// Local dashboard server. Uses YOUR AWS credentials (AWS_PROFILE), listens on localhost only,
// so nothing is exposed publicly.
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { S3Client, ListObjectsV2Command, DeleteObjectCommand, HeadBucketCommand } from "@aws-sdk/client-s3";
import { Upload } from "@aws-sdk/lib-storage";
import { fromIni, fromNodeProviderChain } from "@aws-sdk/credential-providers";

const dir = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 5000;
const ACCOUNT = process.env.ACCOUNT_ID || "201240241262";
const BUCKETS = {
  A: { name: `self-healing-us-east-1-${ACCOUNT}`, region: "us-east-1" },
  B: { name: `self-healing-us-west-2-${ACCOUNT}`, region: "us-west-2" },
};
const credentials = process.env.AWS_PROFILE ? fromIni({ profile: process.env.AWS_PROFILE }) : fromNodeProviderChain();
const clients = Object.fromEntries(
  Object.entries(BUCKETS).map(([k, b]) => [k, new S3Client({ region: b.region, credentials })])
);

const json = (res, code, body) => { res.writeHead(code, { "content-type": "application/json" }); res.end(JSON.stringify(body)); };

async function listSide(side) {
  const { name } = BUCKETS[side];
  try {
    const objects = [];
    let token;
    do {
      const r = await clients[side].send(new ListObjectsV2Command({ Bucket: name, ContinuationToken: token }));
      (r.Contents || []).forEach(o => objects.push({ key: o.Key, size: o.Size, modified: o.LastModified }));
      token = r.NextContinuationToken;
    } while (token);
    return { ...BUCKETS[side], up: true, objects };
  } catch (e) {
    return { ...BUCKETS[side], up: false, objects: [], error: e.name };
  }
}

http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  try {
    if (url.pathname === "/api/state") {
      const [A, B] = await Promise.all([listSide("A"), listSide("B")]);
      return json(res, 200, { A, B });
    }
    if (url.pathname === "/api/upload" && req.method === "PUT") {
      const side = url.searchParams.get("side"), key = url.searchParams.get("key");
      if (!BUCKETS[side] || !key) return json(res, 400, { error: "bad request" });
      await new Upload({
        client: clients[side],
        params: { Bucket: BUCKETS[side].name, Key: key, Body: req, ContentType: req.headers["content-type"] || "application/octet-stream" },
      }).done();
      return json(res, 200, { ok: true });
    }
    if (url.pathname === "/api/delete" && req.method === "POST") {
      const side = url.searchParams.get("side"), key = url.searchParams.get("key");
      if (!BUCKETS[side] || !key) return json(res, 400, { error: "bad request" });
      await clients[side].send(new DeleteObjectCommand({ Bucket: BUCKETS[side].name, Key: key }));
      return json(res, 200, { ok: true });
    }
    if (url.pathname === "/" || url.pathname === "/index.html") {
      res.writeHead(200, { "content-type": "text/html" });
      return res.end(fs.readFileSync(path.join(dir, "index.html")));
    }
    json(res, 404, { error: "not found" });
  } catch (e) {
    json(res, 500, { error: e.message });
  }
}).listen(PORT, "127.0.0.1", () => console.log(`Dashboard: http://localhost:${PORT}`));
