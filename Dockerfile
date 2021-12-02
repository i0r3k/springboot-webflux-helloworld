#################################
# Builder - PIPY
#################################
FROM node:16-buster as builder

ARG CMAKE_VERSION=3.22.0
ARG MAVEN_VERSION=3.6.3
ARG GRAALVM_VERSION=21.3.0
ARG GRAALVM_JAVA_VERSION=11
ARG WORK_DIR=/workspace
ARG PIPY_DIR=${WORK_DIR}/pipy
ARG GRAALVM_ROOT_DIR=${WORK_DIR}/graalvm
ARG GRAALVM_DIR=${GRAALVM_ROOT_DIR}/graalvm-ce-java${GRAALVM_JAVA_VERSION}-${GRAALVM_VERSION}

WORKDIR ${WORK_DIR}

ADD clang-sources.list clang-sources.list
ADD src/ src/
ADD pom.xml pom.xml
ADD .mvn/ .mvn/
ADD mvnw mvnw

ENV DEBIAN_FRONTEND=noninteractive
# ENV CC=clang-13
# ENV CXX=clang++-13
ENV PATH=${GRAALVM_DIR}/bin:${PATH}
ENV JAVA_HOME=${GRAALVM_DIR}

# install dependencies
RUN cd ${WORK_DIR} \
    && wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${GRAALVM_VERSION}/graalvm-ce-java${GRAALVM_JAVA_VERSION}-linux-amd64-${GRAALVM_VERSION}.tar.gz \
    && mkdir -p ${GRAALVM_ROOT_DIR} \
    && tar -xzf graalvm-ce-java${GRAALVM_JAVA_VERSION}-linux-amd64-${GRAALVM_VERSION}.tar.gz -C ${GRAALVM_ROOT_DIR} \
    && cd ${WORK_DIR} \
    && wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz \
    && tar -zxf cmake-${CMAKE_VERSION}.tar.gz \
    && cd ${WORK_DIR}/cmake-${CMAKE_VERSION} \
    && ./bootstrap \
    && make \
    && make install \
    && cat ${WORK_DIR}/clang-sources.list >> /etc/apt/sources.list \
    && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
    && apt-get update \
    && apt-get install -y clang-13 lldb-13 lld-13

# build pipy
RUN cd ${WORK_DIR} \
    && git clone https://github.com/flomesh-io/pipy.git \
    && cd ${PIPY_DIR} \
    && npm install \
    && npm run build \
    && mkdir -p ${PIPY_DIR}/build \
    && cd ${PIPY_DIR}/build \
    && export CC=clang-13 \
    && export CXX=clang++-13 \
    && cmake -DPIPY_GUI=OFF -DPIPY_TUTORIAL=OFF -DCMAKE_BUILD_TYPE=Release ${PIPY_DIR} \
    && make

# build Spring native
RUN cd ${WORK_DIR} \
    && ./mvnw -Pnative -DskipTests package


# #################################
# # Final Image
# #################################
FROM ubuntu:20.04

WORKDIR /func
ENV FAAS_PORT=18080
ENV MAX_IDLE_TIME=60

COPY --from=builder /workspace/pipy/bin/pipy /usr/local/bin
COPY --from=builder /workspace/target/rest-service-complete target/rest-service-complete
COPY pipy.js pipy.js
COPY run.sh run.sh

# RUN apk --no-cache add curl

EXPOSE 8080

ENTRYPOINT ["pipy", "pipy.js"]
