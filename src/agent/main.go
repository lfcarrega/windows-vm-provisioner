package main

import (
	//"crypto/tls"
	"encoding/json"
	"github.com/yusufpapurcu/wmi"
	"fmt"
	"io"
	"net/http"
	"os/exec"
)

const (
	AuthToken  = "SeuTokenSuperSecreto123"
	ListenPort = ":8443" // Porta HTTPS padrão para o seu agente
)

type Win32_ComputerSystem struct {
	Name             string
	TotalPhysicalMemory uint64
	Manufacturer     string
	Model            string
}

type Win32_Processor struct {
	Name          string
	NumberOfCores uint32
	MaxClockSpeed uint32
}

type Win32_DiskDrive struct {
	Model  string
	Size   uint64
	SerialNumber string
}

type Win32_BaseBoard struct {
	SerialNumber string
	Manufacturer string
	Product      string
}

func commandHandler(w http.ResponseWriter, r *http.Request) {
	// 1. Valida o Token de Segurança no Header
	if r.Header.Get("X-Auth-Token") != AuthToken {
		http.Error(w, "Não autorizado", http.StatusUnauthorized)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	// 2. Lê o script PowerShell enviado no corpo da requisição
	scriptBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Erro ao ler script", http.StatusBadRequest)
		return
	}

	// 3. Executa o PowerShell passando o script via Standard Input (Stdin)
	// Isso evita ter que salvar um arquivo temporário no disco!
	cmd := exec.Command(`x:\tools\pwsh\pwsh.exe`, "-NoProfile", "-NonInteractive", "-Command", "-")
	
	stdin, err := cmd.StdinPipe()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Injeta o script no stdin do PowerShell e fecha
	go func() {
		defer stdin.Close()
		stdin.Write(scriptBody)
	}()

	// Captura o STDOUT e o STDERR juntos (equivalente ao 2>&1 do Bash/PS)
	output, err := cmd.CombinedOutput()
	
	// 4. Devolve a resposta do comando para o curl/Ansible
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write(output)
}

func main() {
	
	var cs []Win32_ComputerSystem
	wmi.Query("SELECT * FROM Win32_ComputerSystem", &cs)

	var cpu []Win32_Processor
	wmi.Query("SELECT * FROM Win32_Processor", &cpu)

	var disks []Win32_DiskDrive
	wmi.Query("SELECT * FROM Win32_DiskDrive", &disks)

	var board []Win32_BaseBoard
	wmi.Query("SELECT * FROM Win32_BaseBoard", &board)

	inventory := map[string]any{
		"computer": cs,
		"cpu":      cpu,
		"disks":    disks,
		"board":    board,
	}

	out, _ := json.MarshalIndent(inventory, "", "  ")
	fmt.Println(string(out))


	http.HandleFunc("/", commandHandler)
	fmt.Printf("Agente WinPE escutando em HTTPS %s...\n", ListenPort)

	// Para rodar em HTTPS real, você pode gerar um certificado autoassinado 
	// e embuti-lo na ISO, ou rodar como HTTP normal mudando para ListenAndServe
	err := http.ListenAndServeTLS(ListenPort, `x:\tools\cerberus.crt`, `x:\tools\cerberus.key`, nil)
	
	//err := http.ListenAndServe(ListenPort, nil) // HTTP simples para testes
	if err != nil {
		fmt.Println("Erro ao iniciar o servidor:", err)
	}
}