package service

import (
	"crypto/des"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"strings"
	"unicode/utf8"
)

const MachineMD5Suffix = "_zhuojinchangzhou"

// latin1Bytes 复刻 Python encode("latin1", errors="replace")。
func latin1Bytes(value string) []byte {
	out := make([]byte, 0, len(value))
	for _, r := range value {
		if r > 0xFF {
			out = append(out, '?')
			continue
		}
		out = append(out, byte(r))
	}
	return out
}

// XDESHex 复刻旧版 genbtn：DES/ECB，明文按 8 字节分组并以 0x00 补齐，输出小写 hex。
func XDESHex(text, key string) (string, error) {
	data := latin1Bytes(text)
	keyBytes := latin1Bytes(key)

	if len(data) == 0 {
		return "", fmt.Errorf("请输入 SN。")
	}
	if len(keyBytes) != 8 {
		return "", fmt.Errorf("密钥必须是 8 个 Latin-1 字节。")
	}

	if rem := len(data) % 8; rem != 0 {
		data = append(data, make([]byte, 8-rem)...)
	}

	block, err := des.NewCipher(keyBytes)
	if err != nil {
		return "", fmt.Errorf("DES 初始化失败: %w", err)
	}

	encrypted := make([]byte, len(data))
	for i := 0; i < len(data); i += 8 {
		block.Encrypt(encrypted[i:i+8], data[i:i+8])
	}
	return hex.EncodeToString(encrypted), nil
}

// MachineMD5 复刻旧版 genbtn_2：拼接后缀后按长度截断再做 MD5。
func MachineMD5(machineCode string, md5Length *int, suffix string) (string, error) {
	if suffix == "" {
		suffix = MachineMD5Suffix
	}
	normalized := strings.TrimSpace(machineCode)
	machineBytes := latin1Bytes(normalized)
	suffixBytes := latin1Bytes(suffix)

	length := len(machineBytes)
	if md5Length != nil {
		length = *md5Length
	}
	if length < 0 {
		return "", fmt.Errorf("MD5 长度不能为负数。")
	}

	buffer := append(machineBytes, suffixBytes...)
	if length > len(buffer) {
		length = len(buffer)
	}
	sum := md5.Sum(buffer[:length])
	return hex.EncodeToString(sum[:]), nil
}

func GenerateMachineMD5Payload(machineCode string, md5Length *int) (map[string]any, error) {
	normalized := strings.TrimSpace(machineCode)
	machineBytes := latin1Bytes(normalized)
	effective := len(machineBytes)
	if md5Length != nil {
		effective = *md5Length
	}

	digest, err := MachineMD5(normalized, md5Length, MachineMD5Suffix)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"machine_code":        normalized,
		"machine_md5_suffix":  MachineMD5Suffix,
		"md5_length":          effective,
		"machine_md5":         digest,
		"compatibility_note": fmt.Sprintf(
			"复刻旧版 genbtn_2：先拼接 %q，再按长度 %d 截断后做 MD5。C++ 原版长度取 innerGetMachineCode()（硬盘序列号）字节数；可通过 md5_length 手动指定。",
			MachineMD5Suffix, effective,
		),
	}, nil
}

func GenerateRegisterPayload(sn, key string) (map[string]any, error) {
	normalized := strings.TrimSpace(sn)
	code, err := XDESHex(normalized, key)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"sn":               normalized,
		"key":              key,
		"activation_code":  code,
		"compatibility_note": "复刻旧版 genbtn：对注册码输入执行 DES/XDES，密钥默认使用内置密钥，明文按 8 字节分组并以 0x00 补齐，输出小写十六进制激活码。",
	}, nil
}

func GeneratePayload(machineCode, sn, key string, md5Length *int) (map[string]any, error) {
	md5Result, err := GenerateMachineMD5Payload(machineCode, md5Length)
	if err != nil {
		return nil, err
	}
	regResult, err := GenerateRegisterPayload(sn, key)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"machine_code":       md5Result["machine_code"],
		"sn":                 regResult["sn"],
		"key":                regResult["key"],
		"machine_md5_suffix": md5Result["machine_md5_suffix"],
		"md5_length":         md5Result["md5_length"],
		"machine_md5":        md5Result["machine_md5"],
		"register_code":      regResult["activation_code"],
		"activation_code":    regResult["activation_code"],
		"compatibility_note": fmt.Sprintf("%v %v", md5Result["compatibility_note"], regResult["compatibility_note"]),
	}, nil
}

// KeyLatin1Len 返回密钥的 Latin-1 字节长度（用于校验提示）。
func KeyLatin1Len(key string) int {
	return len(latin1Bytes(key))
}

// EnsureUTF8 避免模板渲染非法 UTF-8。
func EnsureUTF8(s string) string {
	if utf8.ValidString(s) {
		return s
	}
	return strings.ToValidUTF8(s, "?")
}
