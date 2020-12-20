# certificate-scripts

A few scripts to generate some certificates I need to have around.

- `gen-cert-multiple-domain-names.sh`: Generate a pretty typical 2048bit certificate suitable for TLS 1.2 on a webserver. Also optionally supports a secondary domain name (i.e. alternative subject name).

## Todo / Roadmap
- Sigh, probably should replace this with https://cryptography.io/en/latest/x509/tutorial.html#creating-a-self-signed-certificate