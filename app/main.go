package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"sync/atomic"
	"syscall"
	"time"
)

var (
	version   = "dev"
	startedAt = time.Now()
	requests  atomic.Uint64
)

type response struct {
	Status   string `json:"status"`
	Service  string `json:"service"`
	Version  string `json:"version"`
	Hostname string `json:"hostname"`
	Time     string `json:"time"`
}

func serviceName() string {
	if value := os.Getenv("SERVICE_NAME"); value != "" {
		return value
	}
	return "oci-platform-core"
}

func hostname() string {
	name, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return name
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func withMetrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("http_request",
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
			"user_agent", r.UserAgent(),
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, response{
			Status:   "ok",
			Service:  serviceName(),
			Version:  version,
			Hostname: hostname(),
			Time:     time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("GET /ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		fmt.Fprintf(w, "# HELP platform_http_requests_total Total HTTP requests handled\n")
		fmt.Fprintf(w, "# TYPE platform_http_requests_total counter\n")
		fmt.Fprintf(w, "platform_http_requests_total %d\n", requests.Load())
		fmt.Fprintf(w, "# HELP platform_uptime_seconds Seconds since process start\n")
		fmt.Fprintf(w, "# TYPE platform_uptime_seconds gauge\n")
		fmt.Fprintf(w, "platform_uptime_seconds %.0f\n", time.Since(startedAt).Seconds())
		fmt.Fprintf(w, "# HELP platform_build_info Build metadata\n")
		fmt.Fprintf(w, "# TYPE platform_build_info gauge\n")
		fmt.Fprintf(w, "platform_build_info{version=%q,go=%q} 1\n", version, runtime.Version())
	})

	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{
			"service":     serviceName(),
			"version":     version,
			"description": "OCI platform core sample workload",
			"endpoints":   []string{"/health", "/ready", "/metrics"},
			"runtime":     runtime.Version(),
		})
	})

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           withMetrics(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		slog.Info("server_start", "addr", srv.Addr, "version", version)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server_error", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("shutdown_error", "error", err)
	}
	slog.Info("server_stopped")
}
