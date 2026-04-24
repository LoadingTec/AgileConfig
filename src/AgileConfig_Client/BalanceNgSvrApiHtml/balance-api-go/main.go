package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const maxMultipart = 20 << 20 // 20 MiB

func main() {
	uploadDir := filepath.Join(".", "uploads")
	_ = os.MkdirAll(uploadDir, 0o755)

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", withCORS(healthHandler))
	mux.HandleFunc("/api/submit", withCORS(submitHandler(uploadDir)))

	addr := ":5093"
	if p := os.Getenv("PORT"); p != "" {
		if strings.HasPrefix(p, ":") {
			addr = p
		} else {
			addr = ":" + p
		}
	}
	fmt.Println("listening on", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "*")
		w.Header().Set("Access-Control-Allow-Headers", "*")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	host, _ := os.Hostname()
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"utc":     time.Now().UTC().Format(time.RFC3339Nano),
		"machine": host,
	})
}

func submitHandler(uploadDir string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		ct := r.Header.Get("Content-Type")
		if !strings.HasPrefix(ct, "multipart/form-data") {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Content-Type 须为 multipart/form-data"})
			return
		}
		if err := r.ParseMultipartForm(maxMultipart); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
			return
		}
		name := strings.TrimSpace(r.FormValue("name"))
		if name == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name 必填"})
			return
		}
		remark := r.FormValue("remark")

		var savedName any
		var bytes any
		f, hdr, err := r.FormFile("file")
		if err != nil && !errors.Is(err, http.ErrMissingFile) {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
			return
		}
		if err == nil {
			defer f.Close()
			if hdr != nil && hdr.Filename != "" && hdr.Size > 0 {
				safe := filepath.Base(hdr.Filename)
				if safe == "" || safe == "." {
					safe = "upload.bin"
				}
				now := time.Now().UTC()
				stamp := now.Format("20060102150405") + fmt.Sprintf("%03d", now.Nanosecond()/1e6)
				outName := stamp + "_" + safe
				dest := filepath.Join(uploadDir, outName)
				df, err := os.Create(dest)
				if err != nil {
					writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
					return
				}
				n, err := io.Copy(df, f)
				_ = df.Close()
				if err != nil {
					writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
					return
				}
				savedName = outName
				bytes = n
			}
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"message": "已处理",
			"name":    name,
			"remark":  remark,
			"file":    savedName,
			"bytes":   bytes,
		})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
