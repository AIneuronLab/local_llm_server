# Local LLM Server (llama)

A lightweight local LLM server manager using `llama.cpp` (`llama-server`) to run chat and embedding models locally.

## Features

- Run a local chat model.
- Run a local embedding model.
- Start, stop, restart, and monitor servers.
- Configure models and server settings through a `.env` file.

## Requirements

- macOS or Linux
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- Bash
- `curl`
- `jq` (optional)

## Project Structure

```text
local_llm_server/
├── .env
├── .env.example
├── start.sh
├── stop.sh
├── restart.sh
├── status.sh
└── logs/
```

## Configuration

Create your `.env` file:

```bash
cp .env.example .env
```

Update the model paths, ports, and other settings according to your environment.

## Usage

Make the scripts executable:

```bash
chmod +x start.sh stop.sh restart.sh status.sh
```

Start the servers:

```bash
./start.sh
```

Check their status:

```bash
./status.sh
```

Restart the servers:

```bash
./restart.sh
```

Stop the servers:

```bash
./stop.sh
```

## API Endpoints

| Service | Default Port | Endpoint |
|---|---:|---|
| Chat | 8200 | `http://localhost:8200` |
| Embeddings | 8300 | `http://localhost:8300` |

Health checks:

```bash
curl http://localhost:8200/health
curl http://localhost:8300/health
```

## Logs

Server logs are stored in:

```text
logs/chat.log
logs/embed.log
```

## Security

- Never commit your `.env` file.
- Keep API keys and other credentials private.
- The servers bind to `127.0.0.1` by default.

## License

MIT

