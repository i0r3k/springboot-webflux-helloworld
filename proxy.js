pipy()
.listen(8080)
  .demuxHTTP('forward')
.pipeline('forward')
  .muxHTTP('connection', () => __inbound)
.pipeline('connection')
  .connect(() => '127.0.0.1:18080')
