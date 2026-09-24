package api

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/bbpro/go_http/config"
	"github.com/bbpro/go_http/service"
)

type Server struct {
	Cfg *config.Config
}

func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/api", s.cors(s.handleIndex))
	mux.HandleFunc("/api/health", s.cors(s.handleHealth))
	mux.HandleFunc("/api/machine-md5", s.cors(s.handleMachineMD5))
	mux.HandleFunc("/api/register-code", s.cors(s.handleRegisterCode))
	mux.HandleFunc("/api/generate", s.cors(s.handleGenerate))
}

func (s *Server) cors(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "method not allowed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"name":    "RegMachine Web API (Go)",
		"version": "1.0",
		"endpoints": map[string]any{
			"health": map[string]string{"method": "GET", "path": "/api/health"},
			"machine_md5": map[string]any{
				"method": "POST",
				"path":   "/api/machine-md5",
				"body": map[string]string{
					"machine_code": "string, required",
					"md5_length":   "integer, optional, default = machine_code byte length",
				},
			},
			"register_code": map[string]any{
				"method": "POST",
				"path":   "/api/register-code",
				"body": map[string]string{
					"sn":  "string, required",
					"key": "string, optional, 8 bytes, default from server config",
				},
			},
			"generate": map[string]any{
				"method": "POST",
				"path":   "/api/generate",
				"body": map[string]string{
					"machine_code": "string, required",
					"sn":           "string, required",
					"key":          "string, optional, 8 bytes, default from server config",
					"md5_length":   "integer, optional",
				},
			},
		},
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "method not allowed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":      "ok",
		"service":     "regmachine-web-go",
		"default_key": s.Cfg.RegisterKey,
	})
}

func (s *Server) handleMachineMD5(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "method not allowed"})
		return
	}
	body, err := decodeBody(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid json"})
		return
	}
	machineCode, _ := body["machine_code"].(string)
	md5Len, err := parseMD5Length(body["md5_length"])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}
	result, err := service.GenerateMachineMD5Payload(machineCode, md5Len)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *Server) handleRegisterCode(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "method not allowed"})
		return
	}
	body, err := decodeBody(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid json"})
		return
	}
	sn, _ := body["sn"].(string)
	key := s.Cfg.RegisterKey
	if v, ok := body["key"].(string); ok && v != "" {
		key = v
	}
	result, err := service.GenerateRegisterPayload(sn, key)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *Server) handleGenerate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "method not allowed"})
		return
	}
	body, err := decodeBody(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid json"})
		return
	}
	machineCode, _ := body["machine_code"].(string)
	sn, _ := body["sn"].(string)
	key := s.Cfg.RegisterKey
	if v, ok := body["key"].(string); ok && v != "" {
		key = v
	}
	md5Len, err := parseMD5Length(body["md5_length"])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}
	result, err := service.GeneratePayload(machineCode, sn, key, md5Len)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func decodeBody(r *http.Request) (map[string]any, error) {
	defer r.Body.Close()
	data, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return map[string]any{}, nil
	}
	var body map[string]any
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, err
	}
	return body, nil
}

func parseMD5Length(raw any) (*int, error) {
	if raw == nil {
		return nil, nil
	}
	switch v := raw.(type) {
	case float64:
		n := int(v)
		return &n, nil
	case string:
		if v == "" {
			return nil, nil
		}
		n, err := strconv.Atoi(v)
		if err != nil {
			return nil, errors.New("md5_length 必须是整数")
		}
		return &n, nil
	default:
		return nil, errors.New("md5_length 必须是整数")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
