package internal

import (
	"context"
	"syscall"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestProcessMonitor_start_and_wait_for_exit(t *testing.T) {
	pm := NewProcessMonitor([]*Process{
		{Name: "one", CmdString: []string{"true"}},
		{Name: "two", CmdString: []string{"false"}},
	})

	require.NoError(t, pm.Boot())

	result, err := pm.WaitForExit(context.Background())
	require.NoError(t, err)
	assert.NotEqual(t, 0, result)
}

func TestProcessMonitor_timeout_when_waiting_for_exit(t *testing.T) {
	pm := NewProcessMonitor([]*Process{
		{Name: "one", CmdString: []string{"sleep", "10"}},
		{Name: "two", CmdString: []string{"sleep", "10"}},
	})

	require.NoError(t, pm.Boot())

	ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond*20)
	defer cancel()

	_, err := pm.WaitForExit(ctx)
	require.Equal(t, ErrorTimeout, err)
}

func TestProcessMonitor_exit_all_when_once_process_exits_with_success(t *testing.T) {
	pm := NewProcessMonitor([]*Process{
		{Name: "z", CmdString: []string{"true"}},
		{Name: "a", CmdString: []string{"sleep", "10"}},
		{Name: "b", CmdString: []string{"sleep", "10"}},
		{Name: "c", CmdString: []string{"sleep", "10"}},
	})

	require.NoError(t, pm.Boot())
	result, err := pm.WaitForExit(context.Background())
	require.NoError(t, err)
	assert.NotEqual(t, 0, result)
}

func TestProcessMonitor_exit_all_when_once_process_exits_with_error(t *testing.T) {
	pm := NewProcessMonitor([]*Process{
		{Name: "z", CmdString: []string{"false"}},
		{Name: "a", CmdString: []string{"sleep", "10"}},
		{Name: "b", CmdString: []string{"sleep", "10"}},
		{Name: "c", CmdString: []string{"sleep", "10"}},
	})

	require.NoError(t, pm.Boot())
	result, err := pm.WaitForExit(context.Background())
	require.NoError(t, err)
	assert.NotEqual(t, 0, result)
}

func TestProcessMonitor_signal_processes(t *testing.T) {
	pm := NewProcessMonitor([]*Process{
		{Name: "one", CmdString: []string{"sleep", "60"}},
		{Name: "two", CmdString: []string{"sleep", "60"}},
	})

	require.NoError(t, pm.Boot())

	pm.Signal(syscall.SIGTERM)

	result, err := pm.WaitForExit(context.Background())
	require.NoError(t, err)
	assert.NotEqual(t, 0, result)
}
