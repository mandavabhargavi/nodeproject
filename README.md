# Ink Node

> Forked and customized from https://github.com/smartcontracts/simple-optimism-node

A Docker Compose setup for running an Ink node, plus the supporting healthcheck
and monitoring services.

## Recommended Hardware

### Mainnet

- 16GB+ RAM
- 2 TB SSD (NVME recommended)
- 100 Mbps+ download

### Testnet

- 16GB+ RAM
- 500 GB SSD (NVME recommended)
- 100 Mbps+ download

## Prerequisites

- Docker Engine and Docker Compose v2 on Linux, or Docker Desktop on macOS and
  Windows
- Working L1 execution RPC and L1 beacon API endpoints for the Ethereum network
  that matches your target Ink network
- Enough free disk for your chosen node type

On Apple Silicon, the `healthcheck` sidecar runs as `linux/amd64`. Docker
Desktop handles this automatically, but the first startup can take longer.

### Ubuntu install

> If you are not logged in as root, log out and back in after adding yourself to
> the `docker` group.

```sh
sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y curl gnupg ca-certificates lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $(whoami)
```

Verify Docker after logging back in:

```sh
docker ps
```

## Quick Start

### 1. Clone the repo

```sh
git clone https://github.com/inkonchain/node
cd node
```

### 2. Copy the env template

```sh
cp .env.example .env
```

### 3. Edit `.env`

For the lowest-friction first run, start with `ink-sepolia` and a `full` node:

```sh
NETWORK_NAME=ink-sepolia
NODE_TYPE=full
OP_NODE__RPC_ENDPOINT=<your Sepolia execution RPC>
OP_NODE__L1_BEACON=<your Sepolia beacon API>
OP_NODE__RPC_TYPE=basic
HEALTHCHECK__REFERENCE_RPC_PROVIDER=https://rpc-gel-sepolia.inkonchain.com
```

Configuration notes:

- `NETWORK_NAME`: `ink-sepolia` or `ink-mainnet`
- `NODE_TYPE=full`: starts from an empty local datadir
- `NODE_TYPE=archive`: downloads and extracts a network snapshot during
  `bedrock-init`
- `OP_NODE__RPC_TYPE=basic`: the right default for generic providers; use
  `alchemy`, `quicknode`, or `erigon` only when your provider requires it
- `.env` overrides the same variable for services that load `.env` in
  `docker-compose.yml`, including `op-geth`, `op-node`, `healthcheck`, and
  `bedrock-init`
- `envs/<network>/op-node.env` already supplies the network P2P defaults, so
  most first-time setups only need the `.env` values above
- For `ink-mainnet`, switch the healthcheck reference RPC to
  `https://rpc-gel.inkonchain.com`

### 4. Start the stack

```sh
docker compose up -d --build
```

This pulls the service images, builds the local `bedrock-init` image, creates a
JWT, and starts:

- `op-geth`
- `op-node`
- `healthcheck`
- `prometheus`
- `grafana`
- `influxdb`

## Validate Startup

### Check service status

```sh
docker compose ps
```

Expect the long-running services to be `Up`. `bedrock-init` is a one-time init
container, so it will usually disappear from default `docker compose ps` output
once it exits. If you want to confirm it finished successfully, run
`docker compose ps -a` and check that `bedrock-init` exited with code `0`.

### Check the key logs

```sh
docker compose logs --tail 50 bedrock-init op-geth op-node
```

Good startup signals:

- `bedrock-init` on first boot: `Creating JWT...` and `Creating Bedrock flag...`
- `bedrock-init` on restart with existing volumes: `Bedrock node already initialized`
- `op-geth`: `HTTP server started`
- `op-node`: `Rollup node started`

### Smoke test the RPC endpoints

Execution RPC:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://127.0.0.1:9993
```

Rollup node RPC:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"rpc_modules","params":[],"id":1}' http://127.0.0.1:9545
```

Healthcheck metrics:

```sh
curl -fsS http://127.0.0.1:7300/metrics | grep -E 'healthcheck_(reference_height|target_height|height_difference)'
```

On a brand-new `full` node, `eth_blockNumber` can stay at `0x0` for a while.
That is expected. Use `optimism_syncStatus` and the healthcheck metrics to
confirm the node is moving forward during early sync.

### Open Grafana

Grafana is available at [http://localhost:3000](http://localhost:3000).

- Username: `admin`
- Password: `ink`

The preloaded dashboard is `Simple Node Dashboard`.

## Operating The Node

### View logs

```sh
docker compose logs -f --tail 50
```

Or for a single service:

```sh
docker compose logs -f --tail 50 op-node
```

### Stop

```sh
docker compose down
```

This stops the stack without removing data volumes.

### Restart

```sh
docker compose restart
```

### Upgrade

```sh
git pull
docker compose pull
docker compose up -d --build
```

### Wipe All Data

```sh
docker compose down -v
```

This removes all local chain and monitoring data.

## Monitoring

### Estimate remaining sync time

`progress.sh` uses Foundry's `cast` on the host machine.

Install Foundry from [https://getfoundry.sh/](https://getfoundry.sh/) and then
run:

```sh
./progress.sh
```

On a brand-new `full` node, `./progress.sh` can return `Error: Not syncing`
while `eth_blockNumber` is still `0x0`. In that phase, use
`optimism_syncStatus` and the healthcheck metrics from the validation section,
then retry the script after the local block height starts moving.

If you do not want to install `cast`, use the RPC and metrics checks above
instead.

## Troubleshooting

### `bedrock-init` exits quickly on a full node

That is expected. `full` nodes do not download a snapshot. If you want a
snapshot restore path, switch to `NODE_TYPE=archive`.

### `bedrock-init` says `Bedrock node already initialized`

That means the stack is reusing existing Docker volumes. This is expected on
restarts. If you intentionally want a clean first-boot flow, wipe the volumes:

```sh
docker compose down -v
```

### `bedrock-init` takes a long time on an archive node

That is expected while the snapshot is downloading and extracting. Check:

```sh
docker compose logs -f bedrock-init
```

If image pulls or snapshot downloads fail, make sure the host can reach:

- `docker.io`
- `us-docker.pkg.dev`
- `storage.googleapis.com`

### `eth_blockNumber` stays at `0x0` right after startup

That is normal for a fresh `full` node. Check the rollup node instead:

```sh
curl -fsS -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://127.0.0.1:9545
```

### `./progress.sh` says `Error: Not syncing`

That is expected during the earliest part of a fresh `full` node bootstrap. The
script samples `eth_blockNumber` twice over 10 seconds, so it cannot estimate
sync speed until the local execution client starts importing blocks. Use
`optimism_syncStatus` and the healthcheck metrics first, then retry later.

### `op-node` cannot connect to L1

Double-check:

- `OP_NODE__RPC_ENDPOINT`
- `OP_NODE__L1_BEACON`
- `OP_NODE__RPC_TYPE`

Then restart the stack:

```sh
docker compose down
docker compose up -d --build
```

### `Walking back L1Block` appears in the logs

A few reset lines during first startup are normal. If the node keeps printing
them without any L1 progress, verify the L1 endpoints above and restart the
stack.
