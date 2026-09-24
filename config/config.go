package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

// Config 由环境变量加载；本地开发可使用 .env 文件。
type Config struct {
	Host        string
	Port        string
	RegisterKey string
	DefaultSN   string
}

// Load 优先读取当前目录下的 .env（不存在则忽略），再解析环境变量。
func Load() (*Config, error) {
	_ = godotenv.Load()

	cfg := &Config{
		Host:        getEnv("APP_HOST", "0.0.0.0"),
		Port:        getEnv("APP_PORT", getEnv("PORT", "9212")),
		RegisterKey: getEnv("REGISTER_KEY", ""),
		DefaultSN:   getEnv("DEFAULT_SN", ""),
	}
	if cfg.Port == "" {
		return nil, fmt.Errorf("APP_PORT is empty")
	}
	return cfg, nil
}

func (c *Config) Addr() string {
	return fmt.Sprintf("%s:%s", c.Host, c.Port)
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}
