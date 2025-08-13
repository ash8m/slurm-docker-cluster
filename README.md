# Slurm Docker Cluster

<p align="center">
    <b> English | <a href="./readme/README_CN.md">简体中文</a> </b>
</p>

**Slurm Docker Cluster** is a multi-container Slurm cluster designed for rapid
deployment using Docker Compose. This repository simplifies the process of
setting up a robust Slurm environment for development, testing, or lightweight
usage.

## 🏁 Getting Started

To get up and running with Slurm in Docker, make sure you have the following tools installed:

- **[Docker](https://docs.docker.com/get-docker/)**
- **[Docker Compose](https://docs.docker.com/compose/install/)**

Clone the repository:

```bash
git clone https://github.com/giovtorres/slurm-docker-cluster.git
cd slurm-docker-cluster
```

## 📦 Containers and Volumes

This setup consists of the following containers:

- **mysql**: Stores job and cluster data.
- **slurmdbd**: Manages the Slurm database.
- **slurmctld**: The Slurm controller responsible for job and resource management.
- **c1, c2**: Compute nodes (running `slurmd`).
- **ipa-server**: FreeIPA server.

### Persistent Volumes:

- `etc_munge`: Mounted to `/etc/munge`
- `etc_slurm`: Mounted to `/etc/slurm`
- `slurm_jobdir`: Mounted to `/data`
- `var_lib_mysql`: Mounted to `/var/lib/mysql`
- `var_log_slurm`: Mounted to `/var/log/slurm`
- `ipa_data`: Mounted to `/data` in ipa-server

## 🛠️  Building the Docker Image

The version of the Slurm project and the Docker build process can be simplified
by using a `.env` file, which will be automatically picked up by Docker Compose.

Install `podman-compose` to use Podman. This branch, which includes FreeIPA integration, has only been tested with `podman-compose`. You can replace any `docker-compose` commands with `podman-compose`, and they should work as expected.

```bash
 pip3 install podman-compose
```

Update the `SLURM_TAG` and `IMAGE_TAG` found in the `.env` file if needed and
build the image:

```bash
docker compose build
```

Or with `podman-compose`

```bash
podman-compose build
```

Alternatively, you can build the Slurm Docker image locally by specifying the
[SLURM_TAG](https://github.com/SchedMD/slurm/tags) as a build argument and
tagging the container with a version ***(IMAGE_TAG)***:

```bash
docker build --build-arg SLURM_TAG="slurm-21-08-6-1" -t slurm-docker-cluster:21.08.6 .
```

## FreeIPA setup

FreeIPA assigns user UIDs and GIDs that fall outside the default range (100000:65536) configured in `/etc/subuid` and `/etc/subgid` on the host. In a rootless container, these user and group IDs are mapped to the host using the ranges defined in those files.

To successfully switch to a FreeIPA-managed user inside the container, you need to expand the subuid and subgid ranges on the host for the user running Podman.

You can learn more about subuids and subgids in the context of containers [here](https://www.funtoo.org/LXD/What_are_subuids_and_subgids%3F). You can read more about how FreeIPA allocates IDs [here](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/adjusting-id-ranges-manually_configuring-and-managing-idm)

Here, the FreeIPA server is configured in `docker-compose.yaml` to allocate IDs starting from 100000000. By default, it can assigns 200,000 IDs starting from that starting point.

### Update subuid and subgid ranges
Edit `/etc/subuid` and `/etc/subgid` to extend the range for the user running podman. For example, for a user named `username`:

```
username:100000:120000000
```

This reserves 120,000,000 IDs starting from 100000 for that user. The root user inside the container (with UID and GID of 0) will be mapped to subuid and subgid 100000 on the host.

## 🚀 Starting the Cluster

Once the image is built, deploy the cluster with the default version of slurm
using Docker Compose:

```bash
docker compose up -d
```

with podman

```bash
podman-compose up -d
```

To specify a specific version and override what is configured in `.env`, specify
the `IMAGE_TAG`:

```bash
IMAGE_TAG=21.08.6 docker compose up -d
```

This will start up all containers in detached mode. You can monitor their status using:

```bash
docker compose ps
```

Note: `FreeIPA` takes around 5 minutes to set up when starting for the first time. Once set up, the configuration and data are stored in the `ipa_data` volume and will be reused as long as the volume remains available.

## 📝 Register the Cluster

After the containers are up and running, register the cluster with **SlurmDBD**:

```bash
./register_cluster.sh
```

> **Tip**: Wait a few seconds for the daemons to initialize before running the registration script to avoid connection errors like:
> `sacctmgr: error: Problem talking to the database: Connection refused`.

For real-time cluster logs, use:

```bash
docker compose logs -f
```

## 🖥️  Accessing the Cluster

To interact with the Slurm controller, open a shell inside the `slurmctld` container:

```bash
docker exec -it slurmctld bash
```

Now you can run any Slurm command from inside the container:

```bash
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## 🧑‍💻 Submitting Jobs

The cluster mounts the `slurm_jobdir` volume across all nodes, making job files accessible from the `/data` directory. To submit a job:

```bash
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="hostname"
Submitted batch job 2
```

Check the output of the job:

```bash
[root@slurmctld data]# cat slurm-2.out
c1
```

## 🔄 Cluster Management

### Stopping and Restarting:

Stop the cluster without removing the containers:

```bash
docker compose stop
```

Restart it later:

```bash
docker compose start
```

### Deleting the Cluster:

To completely remove the containers and associated volumes:

```bash
docker compose down -v
```

## ⚙️ Advanced Configuration

You can modify Slurm configurations (`slurm.conf`, `slurmdbd.conf`) on the fly without rebuilding the containers. Just run:

```bash
./update_slurmfiles.sh slurm.conf slurmdbd.conf
docker compose restart
```

This makes it easy to add/remove nodes or test new configuration settings dynamically.

## 🤝 Contributing

Contributions are welcomed from the community! If you want to add features, fix bugs, or improve documentation:

1. Fork this repo.
2. Create a new branch: `git checkout -b feature/your-feature`.
3. Submit a pull request.

## 📄 License

This project is licensed under the [MIT License](LICENSE).
