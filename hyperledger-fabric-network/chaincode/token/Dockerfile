FROM golang:1.23
WORKDIR /go/src/token
COPY . .
RUN go mod tidy
RUN go get github.com/hyperledger/fabric-chaincode-go/shim
RUN go get github.com/hyperledger/fabric-contract-api-go/contractapi@v1.2.2
RUN CGO_ENABLED=0 GOOS=linux go build -o token
CMD ["./token"]
