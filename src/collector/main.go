package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const (
	AuthToken  = "SeuTokenSuperSecreto123"
	ListenPort = ":9443"
	OutputDir  = "./inventory"
)

type InventoryData struct {
	Computer struct {
		Name string `json:"Name"`
	} `json:"Computer"`
}

func inventoryHandler(w http.ResponseWriter, r *http.Request) {
	if r.Header.Get("X-Auth-Token") != AuthToken {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading payload", http.StatusBadRequest)
		return
	}

    var inv InventoryData
    filename := fmt.Sprintf("device_%d.json", time.Now().UnixNano())
    
    if err := json.Unmarshal(body, &inv); err == nil && inv.Computer.Name != "" {
        filename = fmt.Sprintf("%s.json", inv.Computer.Name)
    } else if err != nil {
        fmt.Printf("[Collector] Error extracting name from JSON: %v\n", err)
    }

    filePath := filepath.Join(OutputDir, filename)
    err = os.WriteFile(filePath, body, 0644)
    if err != nil {
        fmt.Printf("Error saving the file %s: %v\n", filePath, err)
        http.Error(w, "Internal error while saving the file", http.StatusInternalServerError)
        return
    }

    fmt.Printf("[Collector] Inventory received and saved successfully: %s\n", filePath)
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("Inventory processed"))
}

func main() {
	if err := os.MkdirAll(OutputDir, os.ModePerm); err != nil {
		log.Fatalf("Error while creating the output dir: %v", err)
	}

	http.HandleFunc("/inventory", func(w http.ResponseWriter, r *http.Request) {
		inventoryHandler(w, r)
	})

	fmt.Printf("Collector listening at HTTPS %s...\n", ListenPort)
	
	err := http.ListenAndServeTLS(ListenPort, `./cerberus.crt`, `./cerberus.key`, nil)
	if err != nil {
		fmt.Println("Erro no servidor:", err)
	}
}