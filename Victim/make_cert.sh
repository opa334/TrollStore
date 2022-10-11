set -e
export PATH="/opt/homebrew/Cellar/openssl@3/3.0.5/bin:$PATH"

true && openssl req -newkey rsa:2048 -nodes -keyout root_key.pem -x509 -days 3650 -out root_certificate.pem \
	-subj "/C=CA/O=TrollStore/OU=$1/CN=TrollStore iPhone Root CA" \
	-addext "1.2.840.113635.100.6.2.18=DER:0500" \
	-addext "basicConstraints=critical, CA:true" -addext "keyUsage=critical, digitalSignature, keyCertSign, cRLSign"
true && openssl req -newkey rsa:2048 -nodes -keyout codeca_key.pem -out codeca_certificate.csr \
	-subj "/C=CA/O=TrollStore/OU=$1/CN=TrollStore iPhone Certification Authority" \
	-addext "1.2.840.113635.100.6.2.18=DER:0500" \
	-addext "basicConstraints=critical, CA:true" -addext "keyUsage=critical, keyCertSign, cRLSign"
true && openssl x509 -req -CAkey root_key.pem -CA root_certificate.pem -days 3650 \
	-in codeca_certificate.csr -out codeca_certificate.pem -CAcreateserial -copy_extensions copyall
true && openssl req -newkey rsa:2048 -nodes -keyout dev_key.pem -out dev_certificate.csr \
	-subj "/C=CA/O=TrollStore/OU=$1/CN=TrollStore iPhone OS Application Signing" \
	-addext "basicConstraints=critical, CA:false" \
	-addext "keyUsage = critical, digitalSignature" -addext "extendedKeyUsage = codeSigning" \
	-addext "1.2.840.113635.100.6.1.3=DER:0500"
true && openssl x509 -req -CAkey codeca_key.pem -CA codeca_certificate.pem -days 3650 \
	-in dev_certificate.csr -out dev_certificate.pem -CAcreateserial -copy_extensions copyall
true && cat codeca_certificate.pem root_certificate.pem >certificate_chain.pem
true && /usr/bin/openssl pkcs12 -export -in dev_certificate.pem -inkey dev_key.pem -certfile certificate_chain.pem \
	-keypbe NONE -certpbe NONE -passout pass: \
	-out victim.p12 -name "TrollStore iPhone OS Application Signing"

rm certificate_chain.pem
rm codeca_certificate.csr
rm codeca_certificate.pem
rm codeca_key.pem
rm dev_certificate.csr
rm dev_certificate.pem
rm dev_key.pem
rm root_certificate.pem
rm root_key.pem