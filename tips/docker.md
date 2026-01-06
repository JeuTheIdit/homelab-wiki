# Docker tips

Compilation of [Docker](https://www.docker.com/) and Docker Compose tip and tricks to share.    

## Table of contents
- [Make Docker depend on NFS](#make-docker-depend-on-nfs)
- [Hardening containers](#hardening-containers)
- [Reference](#reference)

## Make Docker depend on NFS
If you have Docker containers that use NFS shares, you may see shutdown hangs when the NFS share is unmounted or disconnected before the container stops. See screenshot below for an example.

> [!NOTE]
> These instrucctions were created for Ubuntu, and even though they contain specific Ubuntu/Debian instructions, the concepts are generic enough and can be applied on most Linux distributions, even on those not based on Debian (for example, CentOS and OpenSUSE).

**SCREENSHOT HERE**

To fix this, make Docker depend on `remote-fs.target` by editing the Docker systemd unit.

```bash
sudo systemctl edit docker.service
```

Add the following, which ensures network filesystems like NFS are mounted before Docker starts and remain until Docker stops.

```bash
[Unit]
Requires=remote-fs.target
After=remote-fs.target
```

Restart the Docker service.

```bash
sudo systemctl restart docker.service
```

## Hardening containers
Below are recommendations to harden docker containers.

> [!WARNING]
> Some of the recommendations below might prohibit the container to run properly. In those cases, it is best to open one thing after another to make the attack-surface minimal.
>
> `docker logs {container}` is your friend, where `{container}` is the container name. AI can help figur eout what the choking-point is.
> 
> Using these settings for publicly exposed containers are lowering the blast radius at a significant level, but it won't remove all risks.

> [!NOTE]
> Everything below is assuming `docker-compose.yml` files, but can also be set using docker directly or settings params in Unraid.

### Run container as as user
Example from Unraid, running as user `nobody` and group `users`.

```bash
user: "99:100"
```

### Turn off tty and stdin
```bash
tty: false
stdin_open: false
```

### Read-only filesystem
> [!WARNING]
> YMMV.

```bash
read_only: true
```

### Set no-new-previlegs
Below ensures that the container cant elevate any privileges after start by itself.

```bash
security_opt:
  - no-new-privileges:true
```

### Remove capabilities
By default, containers get a lot of capabilities (12 if I don't remember wrong). Remove ALL of them, and if the container really needs one or a couple of them, add them spesifically after the `DROP` statement.

```bash
cap_drop:
  - ALL
```

Or, and example from a Plex container.

```bash
cap_drop:
  - NET_RAW
  - NET_ADMIN
  - SYS_ADMIN
```

### Set noexec, nosuid, nodev
Set up the `/tmp-area` in the docker to be noexec, nosuid, nodev and limit it's size. If something downloads a payload to the /tmp within the docker, they won't be able to execute the payload. If you limit size, it won't eat all the resources on your host computer. 

> [!NOTE]
> Sometimes (like with Plex), the software auto-updates. Then set the param to exec instead of noexec, but keep all the rest of them.

```bash
tmpfs:
  - /tmp:rw,noexec,nosuid,nodev,size=512m
```

### Limit container resources
Set limits to containers so they won't run off with all the RAM and CPU resources of the host.

```bash
pids_limit: 512
mem_limit: 3g
cpus: 3
```

### Limit logging
This avoids logging bombs within the docker:

```bash
logging:
  driver: json-file
  options:
    max-size: "50m"
    max-file: "5"
```

### Read-only mount

Mount your volumes as read-only, then containers cannot destroy any of the data. Example for Plex below.

```bash
volumes:
  - /mnt/tank/tv:/tv:ro
  - /mnt/tank/movies:/movies:ro
```

## Reference

- <https://www.reddit.com/r/selfhosted/comments/1pr74r4/comment/nv07sp4/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button>
