/*
 Nemesis: Lockdown - local backend (MITM proxy replacing the shut-down nemesislockdownpc.com)

 No admin rights or hosts file needed. The game and the dedicated server are started with
   -httpproxy=127.0.0.1:8888
 and Engine.ini contains
   [/Script/Engine.NetworkSettings]
   n.VerifyPeer=False
 so UE4 (libcurl) sends all HTTP(S) calls through this proxy and accepts our
 self-signed certificate (cert/, created by the backend itself on first run,
 separately on every computer).

 What it does:
   :8888  HTTP proxy. Requests to nemesislockdownpc.com (http and https/CONNECT)
          are intercepted, logged in full and answered from ./responses/
          (if a file exists for that path) or with a default 200 "{}".
          Everything else (steam-api, ipify, ...) is logged as a single line and
          forwarded to the real server, so Steam and the rest work normally.
   :5757  Fake GameLift "auxproxy" listener: only logs connection attempts
          of the GameLift Server SDK (websocket upgrade) and closes the connection.

 Log: ./nemesis_backend.log (deleted on every start; --keep-log keeps it)
*/

const net = require("net");
const tls = require("tls");
const http = require("http");
const fs = require("fs");
const path = require("path");

const PROXY_PORT = 8888;
const GAMELIFT_PORT = 5757;
const TARGET_HOSTS = new Set(["nemesislockdownpc.com", "www.nemesislockdownpc.com"]);
// when packaged with pkg, the files (cert, responses, log) live next to the exe
const BASE_DIR = process.pkg ? path.dirname(process.execPath) : __dirname;
const LOG_FILE = path.join(BASE_DIR, "nemesis_backend.log");
const RESP_DIR = path.join(BASE_DIR, "responses");
const KEEP_LOG = process.argv.includes("--keep-log");

// self-signed certificate: created on first run (the game does not verify it, n.VerifyPeer=False)
function loadOrCreateCert() {
  const dir = path.join(BASE_DIR, "cert");
  const keyFile = path.join(dir, "key.pem");
  const certFile = path.join(dir, "cert.pem");
  if (!fs.existsSync(keyFile) || !fs.existsSync(certFile)) {
    const forge = require("node-forge");
    const keys = forge.pki.rsa.generateKeyPair(2048);
    const c = forge.pki.createCertificate();
    c.publicKey = keys.publicKey;
    c.serialNumber = "01" + forge.util.bytesToHex(forge.random.getBytesSync(8));
    c.validity.notBefore = new Date();
    c.validity.notAfter = new Date(Date.now() + 3650 * 24 * 3600 * 1000);
    const subject = [{ name: "commonName", value: "nemesislockdownpc.com" }];
    c.setSubject(subject);
    c.setIssuer(subject);
    c.setExtensions([
      { name: "subjectAltName", altNames: [
        { type: 2, value: "nemesislockdownpc.com" },
        { type: 2, value: "*.nemesislockdownpc.com" },
        { type: 2, value: "localhost" },
        { type: 7, ip: "127.0.0.1" },
      ] },
    ]);
    c.sign(keys.privateKey, forge.md.sha256.create());
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(keyFile, forge.pki.privateKeyToPem(keys.privateKey));
    fs.writeFileSync(certFile, forge.pki.certificateToPem(c));
    console.log(`Created new certificate: ${certFile}`);
  }
  return { key: fs.readFileSync(keyFile), cert: fs.readFileSync(certFile) };
}
const cert = loadOrCreateCert();

function ts() {
  return new Date().toISOString().slice(11, 23);
}
function log(text) {
  const line = `[${ts()}] ${text}`;
  console.log(line);
  fs.appendFileSync(LOG_FILE, line + "\n");
}

// --------------------------------------------------------------- responses
// responses/<path with '/' -> '_'>.json  e.g. responses/CheckVersion.php.json
// If the file does not exist -> 200 with "{}".
function pickResponse(reqPath) {
  const clean = reqPath.split("?")[0].replace(/^\/+/, "").replace(/\//g, "_");
  const file = path.join(RESP_DIR, clean + ".json");
  if (fs.existsSync(file)) {
    return { body: fs.readFileSync(file, "utf8"), source: path.basename(file) };
  }
  return { body: "{}", source: "default" };
}

// ------------------------------------------------ intercepted HTTP handler
function interceptHandler(scheme) {
  return (req, res) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      const headers = Object.entries(req.headers)
        .map(([k, v]) => `    ${k}: ${v}`)
        .join("\n");
      const host = req.headers.host || "?";
      const { body: out, source } = pickResponse(req.url);
      log(
        `INTERCEPT ${req.method} ${scheme}://${host}${req.url}\n` +
          `  Headers:\n${headers}\n` +
          `  Body (${body.length} bytes): ${body}\n` +
          `  -> reply 200 (${source}): ${out.slice(0, 300)}\n` +
          "-".repeat(70)
      );
      res.writeHead(200, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(out),
        Connection: "close",
      });
      res.end(out);
    });
  };
}

const httpsIntercept = http.createServer(interceptHandler("https"));
const httpIntercept = http.createServer(interceptHandler("http"));

// ------------------------------------------------------------- proxy :8888
const proxy = http.createServer((req, res) => {
  // plain http:// request through the proxy (absolute URL)
  let url;
  try {
    url = new URL(req.url);
  } catch {
    res.writeHead(400);
    return res.end("bad proxy request");
  }
  if (TARGET_HOSTS.has(url.hostname)) {
    req.url = url.pathname + url.search;
    return httpIntercept.emit("request", req, res);
  }
  log(`PASS ${req.method} ${req.url}`);
  const upstream = http.request(
    { host: url.hostname, port: url.port || 80, method: req.method, path: url.pathname + url.search, headers: req.headers },
    (up) => {
      res.writeHead(up.statusCode, up.headers);
      up.pipe(res);
    }
  );
  upstream.on("error", (e) => {
    log(`PASS error ${req.url}: ${e.message}`);
    res.writeHead(502);
    res.end();
  });
  req.pipe(upstream);
});

proxy.on("connect", (req, clientSocket, head) => {
  const [host, portStr] = req.url.split(":");
  const port = Number(portStr || 443);
  if (TARGET_HOSTS.has(host)) {
    log(`CONNECT ${req.url} -> MITM`);
    clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    const tlsSocket = new tls.TLSSocket(clientSocket, { isServer: true, ...cert });
    tlsSocket.on("error", (e) => log(`TLS error from game: ${e.message}`));
    if (head && head.length) tlsSocket.unshift(head);
    httpsIntercept.emit("connection", tlsSocket);
    return;
  }
  log(`CONNECT ${req.url} -> pass-through`);
  const upstream = net.connect(port, host, () => {
    clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    if (head && head.length) upstream.write(head);
    upstream.pipe(clientSocket);
    clientSocket.pipe(upstream);
  });
  upstream.on("error", (e) => {
    log(`CONNECT ${req.url} upstream error: ${e.message}`);
    clientSocket.end();
  });
  clientSocket.on("error", () => upstream.end());
});

// ------------------------------------------------- GameLift auxproxy :5757
const gamelift = net.createServer((sock) => {
  const chunks = [];
  sock.setTimeout(3000);
  sock.on("data", (d) => chunks.push(d));
  const done = () => {
    const data = Buffer.concat(chunks).toString("utf8");
    log(`GAMELIFT SDK connected to :${GAMELIFT_PORT} from ${sock.remoteAddress}:${sock.remotePort}\n${data.slice(0, 2000)}\n` + "-".repeat(70));
    sock.destroy();
  };
  sock.on("timeout", done);
  sock.on("end", done);
  sock.on("error", () => {});
});

// ------------------------------------------------------------------- start
fs.mkdirSync(RESP_DIR, { recursive: true });
if (!KEEP_LOG) {
  try { fs.unlinkSync(LOG_FILE); } catch {}
}
proxy.listen(PROXY_PORT, "127.0.0.1", () => log(`Proxy listening on 127.0.0.1:${PROXY_PORT} (MITM for ${[...TARGET_HOSTS].join(", ")})`));
gamelift.listen(GAMELIFT_PORT, "127.0.0.1", () => log(`GameLift auxproxy watcher on 127.0.0.1:${GAMELIFT_PORT}`));
process.on("SIGINT", () => {
  log("stopped");
  process.exit(0);
});
