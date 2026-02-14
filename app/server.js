const http = require('http');

const PORT = process.env.PORT || 3000;
const POD_NAME = process.env.POD_NAME || 'unknown';
const NODE_NAME = process.env.NODE_NAME || 'unknown';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const APP_ENV = process.env.APP_ENV || 'development';

const server = http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
    return;
  }

  if (req.url === '/version') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      version: APP_VERSION,
      environment: APP_ENV,
      podName: POD_NAME,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  if (req.url === '/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      podName: POD_NAME,
      nodeName: NODE_NAME,
      version: APP_VERSION,
      environment: APP_ENV,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(`Hello from ArgoCD GitOps!\nVersion: ${APP_VERSION}\nEnvironment: ${APP_ENV}\nPod: ${POD_NAME}\nNode: ${NODE_NAME}\n`);
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Version: ${APP_VERSION}`);
  console.log(`Environment: ${APP_ENV}`);
  console.log(`Pod Name: ${POD_NAME}`);
  console.log(`Node Name: ${NODE_NAME}`);
});
