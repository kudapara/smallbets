package internal

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/exec"
	"sync"
)

var (
	ErrorTimeout = errors.New("Timeout")
)

type Process struct {
	Name         string            `json:"name"`
	CmdString    []string          `json:"cmd"`
	Environment  map[string]string `json:"env"`
	Dependencies []string          `json:"dependencies"`

	cmd     *exec.Cmd
	monitor *ProcessMonitor
}

type Processes []*Process

type ProcessMonitor struct {
	processes Processes
	results   chan int

	shutdown bool
	lock     sync.Mutex
}

func NewProcessMonitor(processes Processes) *ProcessMonitor {
	return &ProcessMonitor{
		processes: processes,
		results:   make(chan int, len(processes)),
	}
}

func (pm *ProcessMonitor) Boot() error {
	for _, p := range pm.processes {
		p := p
		p.prepare(pm)
	}

	for _, p := range pm.processes {
		p := p
		err := p.start()
		if err != nil {
			slog.Error("Failed to boot process", "name", p.Name, "error", err)
			pm.terminateAll()
			return err
		}
	}

	return nil
}

func (pm *ProcessMonitor) WaitForExit(ctx context.Context) (int, error) {
	result := 0

	for range pm.processes {
		select {
		case <-ctx.Done():
			pm.terminateAll()
			return 0, ErrorTimeout
		case processResult := <-pm.results:
			if result == 0 {
				result = processResult
			}
		}
	}

	return result, nil
}

func (pm *ProcessMonitor) Signal(signal os.Signal) {
	slog.Info("Relaying signal to all processes", "signal", signal)
	for _, p := range pm.processes {
		p := p
		p.cmd.Process.Signal(signal)
	}
}

func (pm *ProcessMonitor) terminateAll() {
	pm.lock.Lock()
	defer pm.lock.Unlock()

	if !pm.shutdown {
		pm.shutdown = true

		for _, p := range pm.processes {
			p := p
			if p.cmd.Process != nil {
				p.cmd.Process.Kill() // TODO: term, then wait, then kill if needed
			}
		}
	}
}

func (p *Process) prepare(monitor *ProcessMonitor) {
	p.monitor = monitor

	p.cmd = exec.Command(p.CmdString[0], p.CmdString[1:]...)
	p.cmd.Env = append(p.cmd.Environ(), p.formatEnvironmentStrings()...)
	p.cmd.Stdout = os.Stdout
	p.cmd.Stderr = os.Stderr
}

func (p *Process) start() error {
	p.monitor.lock.Lock()
	defer p.monitor.lock.Unlock()

	if p.monitor.shutdown {
		slog.Info("Process not booting; shutdown in progress", "name", p.Name)
		p.monitor.results <- 0
		return nil
	}

	slog.Info("Booting process", "name", p.Name)
	err := p.cmd.Start()
	if err == nil {
		go p.monitorProcess()
	}

	return err
}

func (p *Process) formatEnvironmentStrings() []string {
	var env []string
	for k, v := range p.Environment {
		env = append(env, k+"="+v)
	}
	return env
}

func (p *Process) monitorProcess() {
	slog.Info("Monitoring process", "name", p.Name)

	exitCode := 0
	err := p.cmd.Wait()

	if err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			slog.Error("Process exited with non-zero exit code", "name", p.Name, "exit_code", exiterr.ExitCode())
			exitCode = exiterr.ExitCode()
		} else {
			slog.Error("Error waiting for accessory", "name", p.Name, "error", err)
		}
	} else {
		slog.Info("Process exited with success", "name", p.Name)
	}

	p.monitor.results <- exitCode
	p.monitor.terminateAll()
}
