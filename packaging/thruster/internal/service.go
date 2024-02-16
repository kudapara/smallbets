package internal

import (
	"fmt"
	"net/url"
	"os"
)

type Service struct {
	config *Config
}

func NewService(config *Config) *Service {
	return &Service{
		config: config,
	}
}

func (s *Service) Run() int {
	targetUrl, _ := url.Parse(fmt.Sprintf("http://localhost:%d", s.config.TargetPort))
	cache := NewMemoryCache(s.config.CacheSizeBytes, s.config.MaxCacheItemSizeBytes)

	handler := NewHandler(cache, targetUrl, s.config.XSendfileEnabled, s.config.MaxCacheItemSizeBytes, s.config.BadGatewayPage)
	server := NewServer(s.config, handler)
	upstream := NewUpstreamProcess(s.config.UpstreamCommand, s.config.UpstreamArgs...)

	server.Start()
	defer server.Stop()

	// Set PORT to be inherited by the upstream process.
	os.Setenv("PORT", fmt.Sprintf("%d", s.config.TargetPort))

	exitCode, err := upstream.Run()
	if err != nil {
		panic(err)
	}

	return exitCode
}
