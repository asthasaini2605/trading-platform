const http = require("http");
const fs = require("fs");
const path = require("path");

const server = http.createServer((req, res) => {
  let file = req.url === "/" ? "/index.html" : req.url;
  const filePath = path.join(__dirname, file);

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.writeHead(200);
    res.end(content);
  });
});

server.listen(8080, () => {
  console.log("UI running at http://127.0.0.1:8080");
});
