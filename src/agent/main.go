package main

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"time"
)

const (
	AuthToken        = "SeuTokenSuperSecreto123"
	ListenPort       = ":8443"
	CollectorAddress = "https://192.168.15.192:9443/inventory"
	PwshPath         = `x:\tools\pwsh\pwsh.exe`
	InventoryScript  = `x:\tools\inventory.ps1`
)

func commandHandler(w http.ResponseWriter, r *http.Request) {
	if r.Header.Get("X-Auth-Token") != AuthToken {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	scriptBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading the script", http.StatusBadRequest)
		return
	}

	cmd := exec.Command(PwshPath, "-NoProfile", "-NonInteractive", "-Command", "-")
	
	stdin, err := cmd.StdinPipe()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	go func() {
		defer stdin.Close()
		stdin.Write(scriptBody)
	}()

	output, err := cmd.CombinedOutput()
	
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write(output)
}

func sendInventory() {
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}

	for {
		fmt.Println("[Inventory] Collecting data...")
		
		cmd := exec.Command(PwshPath, "-NoProfile", "-NonInteractive", "-File", InventoryScript)
		output, err := cmd.Output()
		if err != nil {
			fmt.Printf("[Inventory] Error while running script: %v. Trying again in 5s...\n", err)
			time.Sleep(5 * time.Second)
			continue
		}

		req, err := http.NewRequest("POST", CollectorAddress, bytes.NewBuffer(output))
		if err != nil {
			fmt.Printf("Inventory] Error while running script: %v. Trying again in 5s...\n", err)
			time.Sleep(5 * time.Second)
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Auth-Token", AuthToken)

		resp, err := client.Do(req)
		if err != nil {
			fmt.Printf("[Inventory] Network error: %v. Trying again in 5s...\n", err)
			time.Sleep(5 * time.Second)
			continue
		}

		if resp.StatusCode == http.StatusOK {
			fmt.Println("[Inventory] Successfully sent data to the collector!")
			resp.Body.Close()
			break
		}

		fmt.Printf("[Inventory] Server returned status %d. Trying again in 5s...\n", resp.StatusCode)
		resp.Body.Close()
		time.Sleep(5 * time.Second)
	}
}

func main() {
	go sendInventory()

	http.HandleFunc("/", commandHandler)
	fmt.Printf("WinPE agent listening at HTTPS %s...\n", ListenPort)

	err := http.ListenAndServeTLS(ListenPort, `x:\tools\cerberus.crt`, `x:\tools\cerberus.key`, nil)
	if err != nil {
		fmt.Println("Error while starting the server:", err)
	}
}