# Gadgetron Docker Setup

This repository contains a Docker-based setup for running Gadgetron, a
framework for medical image reconstruction, with ISMRMRD format support.

## Quick Overview

This setup provides:
- A Gadgetron server with GPU support
- An ISMRMRD storage server
- A convenient client wrapper script

## Requirements

- Docker or Podman
- NVIDIA GPU with proper drivers (for GPU acceleration)
- NVIDIA Container Toolkit (for GPU support)

## Getting Started

### 1. Start the Gadgetron Server

Start the Gadgetron server and storage backend:

```bash
docker-compose up -d
```

This starts:
- The Gadgetron server on port 27001
- An MRD storage server on port 27002

### 2. Process Data Using the Client

Use the provided wrapper script to send data to the Gadgetron server:

```bash
./gadgetron-client.sh --input your_data.h5 --config default.xml
```

For more options use the help command.

```bash
./gadgetron-client.sh --help
```

## Data Storage

Processed data is stored in the `./mrd_data` directory by default.

## Example Workflow

1. Start services:
   ```bash
   docker-compose up -d
   ```

2. Process MR data:
   ```bash
   ./gadgetron-client.sh --input raw_scan.h5 --output reconstructed.h5 --config my_recon.xml
   ```

3. Retrieve processed results from `./data/reconstructed.h5` (or use `--copy-result` to have it copied automatically)

## Stopping Services

```bash
docker-compose down
```

