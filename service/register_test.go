package service

import "testing"

func TestXDESHex(t *testing.T) {
	code, err := XDESHex("TEST-SN-001", "tech2000")
	if err != nil {
		t.Fatal(err)
	}
	if code == "" {
		t.Fatal("empty activation code")
	}
	if len(code)%16 != 0 {
		t.Fatalf("hex length should be multiple of 16, got %d: %s", len(code), code)
	}
}

func TestXDESHexEmptySN(t *testing.T) {
	_, err := XDESHex("   ", "tech2000")
	// latin1 of spaces is non-empty; empty after strip is caller's job
	if err != nil {
		// XDESHex does not strip; empty string should error
	}
	_, err = XDESHex("", "tech2000")
	if err == nil {
		t.Fatal("expected error for empty sn")
	}
}

func TestXDESHexBadKey(t *testing.T) {
	_, err := XDESHex("abc", "short")
	if err == nil {
		t.Fatal("expected key length error")
	}
}

func TestMachineMD5(t *testing.T) {
	digest, err := MachineMD5("DISK123", nil, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(digest) != 32 {
		t.Fatalf("md5 hex len = %d", len(digest))
	}
}

func TestGenerateRegisterPayload(t *testing.T) {
	result, err := GenerateRegisterPayload("  hello  ", "tech2000")
	if err != nil {
		t.Fatal(err)
	}
	if result["sn"] != "hello" {
		t.Fatalf("sn not trimmed: %v", result["sn"])
	}
	if result["activation_code"] == "" {
		t.Fatal("missing activation_code")
	}
}
