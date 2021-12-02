#!/bin/sh

./target/springboot-webflux-helloworld -Dserver.port=${FAAS_PORT} &
