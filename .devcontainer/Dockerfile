FROM postgres:13

RUN apt-get update && apt-get -yq install build-essential postgresql-server-dev-13
RUN apt-get -yq install sudo

#  Add new user docker to sudo group
RUN adduser postgres sudo
RUN usermod -a -G root postgres
RUN chown -R postgres /usr

# Ensure sudo group users are not 
# asked for a password when using 
# sudo command by ammending sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p /workspace

EXPOSE 5432