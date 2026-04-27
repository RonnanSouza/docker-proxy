FROM debian:bookworm-slim AS proxy-builder

WORKDIR /proxy/

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update -y -q && apt install -y -q g++ make libboost-all-dev dpkg-dev git

RUN git clone https://github.com/MengRao/TCP-UDP-Proxy.git .
RUN git config --global advice.detachedHead false
RUN git checkout 3c0ab60641886c48d223d408dcc81afa50b7a7be
RUN cd src && sed -i "s|/usr/local/lib|/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)|" Makefile \
 && sed -i "s/-Werror/-Werror -Wno-error=deprecated-declarations -DBOOST_BIND_GLOBAL_PLACEHOLDERS/" Makefile \
 && sed -i 's|acceptor\.get_io_service()|static_cast<boost::asio::io_service\&>(acceptor.get_executor().context())|' tcp_proxy.h \
 && sed -i 's|ept->proxy_socket\.get_io_service()|static_cast<boost::asio::io_service\&>(ept->proxy_socket.get_executor().context())|' udp_proxy.cpp \
 && sed -i '1i #include <boost/bind.hpp>' tcp_proxy.cpp udp_proxy.cpp ip_proxy.cpp \
 && sed -i '1i #include <boost/core/noncopyable.hpp>' tcp_proxy.h io_service_pool.h
RUN cd src && make

FROM debian:bookworm-slim

LABEL maintainer="Ronan Souza <ronanpalmeiras@gmail.com>"

ENV LOCAL_PORT=0
ENV REMOTE_PORT=0
ENV REMOTE_IP=127.0.0.1
ENV PROTOCOL=udp

WORKDIR /proxy/

COPY --from=proxy-builder /root/proxy_server .

ENTRYPOINT echo "$PROTOCOL $LOCAL_PORT $REMOTE_IP $REMOTE_PORT" >> proxy.conf && ./proxy_server
