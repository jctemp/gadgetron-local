FROM ghcr.io/gadgetron/gadgetron/gadgetron_ubuntu_rt_nocuda:latest
WORKDIR /home/vscode
ENTRYPOINT [ "/opt/conda/envs/gadgetron/bin/gadgetron_ismrmrd_client" ]

