FROM perl:5.24.0
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
