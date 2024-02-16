package internal

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	"log/slog"

	"github.com/klauspost/compress/gzhttp"
)

func NewHandler(cache *MemoryCache, targetUrl *url.URL, xSendfileEnabled bool, maxCacheableResponseBody int, badGatewayPage string) http.Handler {
	proxy := httputil.NewSingleHostReverseProxy(targetUrl)
	proxy.ErrorHandler = ProxyErrorHandler(badGatewayPage)

	cacheHandler := NewCacheHandler(cache, maxCacheableResponseBody, proxy)
	sendfileHandler := NewSendfileHandler(xSendfileEnabled, cacheHandler)
	gzipHandler := gzhttp.GzipHandler(sendfileHandler)
	loggingHandler := NewLoggingMiddleware(slog.Default(), gzipHandler)

	return loggingHandler
}

func ProxyErrorHandler(badGatewayPage string) func(w http.ResponseWriter, r *http.Request, err error) {
	content, err := os.ReadFile(badGatewayPage)
	if err != nil {
		slog.Info("No custom 502 page found", "path", badGatewayPage)
		content = nil
	}

	return func(w http.ResponseWriter, r *http.Request, err error) {
		slog.Info("Unable to proxy request", "path", r.URL.Path, "error", err)

		if content != nil {
			w.Header().Set("Content-Type", "text/html")
			w.WriteHeader(http.StatusBadGateway)
			w.Write(content)
		} else {
			w.WriteHeader(http.StatusBadGateway)
		}
	}
}
