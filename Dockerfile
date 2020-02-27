# May be built from x86_64, using cross-build-start magic.

# Use the official Golang image to create a build artifact.
# This is based on Debian and sets the GOPATH to /go.
# https://hub.docker.com/_/golang
FROM golang:1.14 as gobuilder

# Create and change to the app directory.
WORKDIR /app

# Retrieve application dependencies.
# This allows the container build to reuse cached dependencies.
COPY go.* ./
RUN go mod download

# Copy local code to the container image.
COPY . ./

# Build the binary.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=6 go build -mod=readonly -a -v rtl_433_prometheus.go

FROM balenalib/raspberrypi3:build as cbuilder

# https://www.balena.io/docs/reference/base-images/base-images/#building-arm-containers-on-x86-machines
RUN [ "cross-build-start" ]

RUN apt-get update && apt-get install -y git libusb-1.0.0-dev librtlsdr-dev rtl-sdr cmake automake
WORKDIR /tmp/
RUN git clone https://github.com/mhansen/rtl_433.git && \
    cd rtl_433 && \
    mkdir build && \
    cd build && \
    cmake ../ && \
    make -j4 rtl_433 && \
    make install && \
    cd / && \
    rm -rf /tmp

# https://www.balena.io/docs/reference/base-images/base-images/#building-arm-containers-on-x86-machines
RUN [ "cross-build-end" ]

FROM balenalib/raspberrypi3:run

# https://www.balena.io/docs/reference/base-images/base-images/#building-arm-containers-on-x86-machines
RUN [ "cross-build-start" ]

RUN apt-get update && apt-get install -y librtlsdr0

WORKDIR /
COPY --from=gobuilder /app/rtl_433_prometheus /
COPY --from=cbuilder /usr/local/bin/rtl_433 /
RUN chmod +x /rtl_433

# https://www.balena.io/docs/reference/base-images/base-images/#building-arm-containers-on-x86-machines
RUN [ "cross-build-end" ]

EXPOSE 9550
ENTRYPOINT ["/rtl_433_prometheus"]
CMD ["--subprocess", "/rtl_433 -F json -M newmodel"]

