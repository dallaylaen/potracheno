FROM perl:5.24.0
# Required 64bit system

# You can build your own 32bit image. Smth like this:
# debootstrap --include cpanminus,perl,gcc jessie rootfs
# tar -cpf rootfs.tar rootfs && cat rootfs.tar | docker import

# Build image:
# docker build -t potracheno .
# Run:
# docker run -d -p 5000:5000 potracheno

MAINTAINER Denis Zheleztsov <difrex.punk@gmail.com>

COPY . /app

# Install dependencies
RUN cpanm DBD::SQLite Text::Markdown MVC::Neaf JSON::XS LWP::UserAgent
RUN cd /app && perl Install.PL --install

ENTRYPOINT cd /app && plackup bin/potracheno.psgi
