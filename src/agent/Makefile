.PHONY: build

all: build

build:
	@echo "Building Agent..."
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o agent.exe .
