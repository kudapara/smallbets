package internal

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHandlerGzipCompression_when_proxying(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", strconv.FormatInt(fixtureLength("loremipsum.txt"), 10))
		w.Write(fixtureContent("loremipsum.txt"))
	}))
	defer upstream.Close()

	upstreamURL, _ := url.Parse(upstream.URL)
	h := NewHandler(NewMemoryCache(defaultCacheSize, defaultMaxCacheItemSizeBytes), upstreamURL, true, 1024, "")

	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set("Accept-Encoding", "gzip")
	h.ServeHTTP(w, r)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Header().Get("Content-Type"), "text/plain")
	assert.Equal(t, "gzip", w.Header().Get("Content-Encoding"))

	transferredSize, _ := strconv.ParseInt(w.Header().Get("Content-Length"), 10, 64)
	assert.Less(t, transferredSize, fixtureLength("loremipsum.txt"))
}

func TestHandlerGzipCompression_does_not_compress_images(t *testing.T) {
	fixtureLength := strconv.FormatInt(fixtureLength("image.jpg"), 10)

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/jpg")
		w.Header().Set("Content-Length", fixtureLength)
		w.Write(fixtureContent("image.jpg"))
	}))
	defer upstream.Close()

	upstreamURL, _ := url.Parse(upstream.URL)
	h := NewHandler(NewMemoryCache(defaultCacheSize, defaultMaxCacheItemSizeBytes), upstreamURL, true, 1024, "")

	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set("Accept-Encoding", "gzip")
	h.ServeHTTP(w, r)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Header().Get("Content-Type"), "image/jpg")
	assert.NotEqual(t, "gzip", w.Header().Get("Content-Encoding"))
	assert.Equal(t, fixtureLength, w.Header().Get("Content-Length"))
}

func TestHandlerGzipCompression_when_sendfile(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "X-Sendfile", r.Header.Get("X-Sendfile-Type"))

		w.Header().Set("X-Sendfile", fixturePath("loremipsum.txt"))
		w.Write([]byte("This body should not be seen"))
	}))
	defer upstream.Close()

	upstreamURL, _ := url.Parse(upstream.URL)
	h := NewHandler(NewMemoryCache(defaultCacheSize, defaultMaxCacheItemSizeBytes), upstreamURL, true, 1024, "")

	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set("Accept-Encoding", "gzip")
	h.ServeHTTP(w, r)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Contains(t, w.Header().Get("Content-Type"), "text/plain")
	assert.Equal(t, "gzip", w.Header().Get("Content-Encoding"))

	transferredSize, _ := strconv.ParseInt(w.Header().Get("Content-Length"), 10, 64)
	assert.Less(t, transferredSize, fixtureLength("loremipsum.txt"))
}
