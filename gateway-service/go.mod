module github.com/KilloSoftwares/MerryNet/gateway-service

go 1.24.0

require (
	github.com/KilloSoftwares/MerryNet/skyos/core v0.0.0
	github.com/KilloSoftwares/MerryNet/skyos/services v0.0.0-00010101000000-000000000000
	github.com/joho/godotenv v1.5.1
	github.com/prometheus/client_golang v1.18.0
	github.com/sirupsen/logrus v1.9.3
	golang.zx2c4.com/wireguard/wgctrl v0.0.0-20241231184526-a9ab2273dd10
	google.golang.org/grpc v1.79.3
	google.golang.org/protobuf v1.36.10
)

replace github.com/KilloSoftwares/MerryNet/skyos/core => ../skyos/core

replace github.com/KilloSoftwares/MerryNet/skyos/services => ../skyos/services

require (
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/josharian/native v1.1.0 // indirect
	github.com/matttproud/golang_protobuf_extensions/v2 v2.0.0 // indirect
	github.com/mdlayher/genetlink v1.3.2 // indirect
	github.com/mdlayher/netlink v1.7.2 // indirect
	github.com/mdlayher/socket v0.5.1 // indirect
	github.com/prometheus/client_model v0.5.0 // indirect
	github.com/prometheus/common v0.45.0 // indirect
	github.com/prometheus/procfs v0.12.0 // indirect
	github.com/stretchr/testify v1.9.0 // indirect
	golang.org/x/crypto v0.46.0 // indirect
	golang.org/x/net v0.48.0 // indirect
	golang.org/x/sync v0.19.0 // indirect
	golang.org/x/sys v0.39.0 // indirect
	golang.org/x/text v0.32.0 // indirect
	golang.zx2c4.com/wireguard v0.0.0-20231211153847-12269c276173 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251202230838-ff82c1b0f217 // indirect
)
