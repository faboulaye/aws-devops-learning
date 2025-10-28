# aws-devops-learning

## Node + Express app: Hostname and Version

This project is a minimal Node.js app using Express that serves a responsive frontend. The UI displays the server hostname and the application version. It also exposes a simple health endpoint.

### Requirements

- Node.js 18+

### Install

```bash
npm install
```

### Run

```bash
# default to port 3000
npm start

# or specify a different port
PORT=3000 npm start
```

Open `http://localhost:3000` in your browser.

### Endpoints

- `GET /api/info` → `{ hostname, version }`
- `GET /healthz` → `{ status: "OK", time: "<ISO timestamp>" }`

### Project structure

```txt
app/
  public/
    index.html     # Responsive UI fetching /api/info
    styles.css     # Optional overrides
  server.js        # Express server, static hosting, endpoints
package.json       # Scripts and dependencies
```

### Notes

- Hostname is read from the OS via `os.hostname()`.
- Version is read from `package.json`.
