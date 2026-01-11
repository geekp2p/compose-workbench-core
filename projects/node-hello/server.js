const express = require("express");
const os = require("os");

const app = express();
const port = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    project: "node-hello",
    language: "node",
    hostname: os.hostname(),
    note: "If you can see this JSON, Docker build + port mapping works."
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`node-hello listening on :${port}`);
});
